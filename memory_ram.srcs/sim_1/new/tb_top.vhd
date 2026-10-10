--------------------------------------------------------------------------------
-- LIBRARY and PACKAGE DECLARATIONS
--------------------------------------------------------------------------------
-- standard package
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--------------------------------------------------------------------------------
-- TESTBENCH ENTITY
--------------------------------------------------------------------------------
entity tb_top is
generic(
c_clkfreq 		: integer 	:= 100_000_000;
c_baudrate 		: integer 	:= 115_200;
RAM_WIDTH 		: integer 	:= 16;                      -- Specify RAM data width
RAM_DEPTH 		: integer 	:= 128;                    	-- Specify RAM depth (number of entries)
RAM_PERFORMANCE : string 	:= "LOW_LATENCY";      		-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
INIT_FILE 		: string 	:= "RAM_INIT.dat"           -- Specify name/location of RAM initialization file if using one (leave blank if not)
);
end tb_top;

--------------------------------------------------------------------------------
-- TESTBENCH ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of tb_top is

----------------------------------------------------------------------------
--  COMPONENT INSTANTIATION
----------------------------------------------------------------------------
component top is
generic(
c_clkfreq 		: integer 	:= 100_000_000;
c_baudrate 		: integer 	:= 9600;
RAM_WIDTH 		: integer 	:= 16;                      -- Specify RAM data width
RAM_DEPTH 		: integer 	:= 128;                    	-- Specify RAM depth (number of entries)
RAM_PERFORMANCE : string 	:= "LOW_LATENCY";      		-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
INIT_FILE 		: string 	:= "RAM_INIT.dat"           -- Specify name/location of RAM initialization file if using one (leave blank if not)
);
port(
clk 	: in std_logic;
rx_i 	: in std_logic;
tx_o 	: out std_logic
);
end component;

component uart_rx is
generic(
c_clkfreq 	: integer 	:= 100_000_000;
c_baudrate 	: integer 	:= 115_200
);
port(
clk 			: in std_logic;
rx_i 			: in std_logic ;
dout_o 			: out std_logic_vector(7 downto 0);
rx_done_tick_o	: out std_logic
);
end component; 


----------------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------------
constant c_clkperiod : time := 10 ns;
constant c_baud115200 	: time := 8.68 us;

----------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------
signal tx_o 			: std_logic;
signal rx_i 			: std_logic := '1';
signal clk 				: std_logic := '0';             
signal dout_o           : std_logic_vector(7 downto 0);
signal rx_done_tick_o   : std_logic;


procedure send_byte(
    constant data : in  std_logic_vector(7 downto 0);
	signal rx_i	  : out std_logic
) is
	variable data_package : std_logic_vector(9 downto 0);
begin
	data_package := '1' & data(7 downto 0) & '0';
	for i in 0 to 9 loop
		rx_i <= data_package(i);
		wait for c_baud115200;
	end loop;    
end procedure;

procedure uart_write(
    constant addr : in  std_logic_vector(7 downto 0);
    constant data : in  std_logic_vector(15 downto 0);
	signal rx_i	  : out std_logic
) is
begin
	send_byte(data => x"0A", rx_i => rx_i);
	send_byte(data => addr, rx_i => rx_i);
	send_byte(data => data(15 downto 8), rx_i => rx_i);
	send_byte(data => data(7 downto 0), rx_i => rx_i);   
end procedure;

procedure uart_read(
    constant addr : in  std_logic_vector(7 downto 0);
	signal rx_i	  : out std_logic
) is
begin
	send_byte(data => x"0B", rx_i => rx_i);
	send_byte(data => addr, rx_i => rx_i);
	send_byte(data => x"00", rx_i => rx_i);
	send_byte(data => x"00", rx_i => rx_i);  
end procedure;

----------------------------------------------------------------------------
-- BEGIN
----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- UUT (Unit Under Test) 
----------------------------------------------------------------------------
UUT_TOP : top
generic map(
c_clkfreq 		=> c_clkfreq 		,
c_baudrate 		=> c_baudrate 		,
RAM_WIDTH 		=> RAM_WIDTH 		,
RAM_DEPTH 		=> RAM_DEPTH 		,
RAM_PERFORMANCE => RAM_PERFORMANCE  ,
INIT_FILE 		=> INIT_FILE 		
)
port map(
clk 	=>   clk   ,
rx_i 	=>   rx_i  ,
tx_o 	=>   tx_o
);

UUT_UART_RX : uart_rx
generic map(
c_clkfreq  =>   c_clkfreq ,
c_baudrate =>   c_baudrate
)
port map(
clk            	=> clk           ,
rx_i           	=> tx_o          ,
dout_o         	=> dout_o        ,
rx_done_tick_o  => rx_done_tick_o 
);

----------------------------------------------------------------------------
-- CLOCK GENERATOR PROCESS
----------------------------------------------------------------------------
P_CLKGEN : process begin
CLK <= '0';
wait for c_clkperiod/2;
CLK <= '1';
wait for c_clkperiod/2;
end process;

----------------------------------------------------------------------------
-- STIMULUS PROCESS
----------------------------------------------------------------------------
P_STIMULI: process 
	variable read_data : std_logic_vector(15 downto 0);
begin

wait for 250 us;

uart_write(addr => x"05", data => x"1122", rx_i => rx_i);
wait for 250 us;

uart_read(addr => x"05", rx_i => rx_i);
wait until rx_done_tick_o = '1';
read_data(15 downto 8) := dout_o;
wait until rx_done_tick_o = '1';
read_data(7 downto 0) := dout_o;

if (read_data = x"1122") then
    report "Expected: 0x1122 | Received: 0x" & to_hstring(to_bitvector(read_data))  
	severity note;
end if;

wait for 250 us;

uart_write(addr => x"25", data => x"0960", rx_i => rx_i);
wait for 250 us;

read_data := x"0000";
uart_read(addr => x"25", rx_i => rx_i);
wait until rx_done_tick_o = '1';
read_data(15 downto 8) := dout_o;
wait until rx_done_tick_o = '1';
read_data(7 downto 0) := dout_o;

if (read_data = x"0960") then
    report "Expected: 0x0960 | Received: 0x" & to_hstring(to_bitvector(read_data)) 
	severity note;
end if;


assert false
report "SIM DONE"
severity failure;

end process;

end Behavioral;
