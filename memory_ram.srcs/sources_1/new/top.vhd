--------------------------------------------------------------------------------
-- LIBRARY and PACKAGE DECLARATIONS
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.ram_pkg.all;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity top is
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
end top;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of top is

--------------------------------------------------------------------------------
-- COMPONENT DECLARATIONS
--------------------------------------------------------------------------------

component block_ram is
generic (
RAM_WIDTH 		: integer 	:= 16;                      -- Specify RAM data width
RAM_DEPTH 		: integer 	:= 128;                    	-- Specify RAM depth (number of entries)
RAM_PERFORMANCE : string 	:= "LOW_LATENCY"      		-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
);

port (
addra : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);        -- Address bus, width determined from RAM_DEPTH
dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);		  			-- RAM input data
clka  : in std_logic;                       			  			-- Clock
wea   : in std_logic;        
douta : out std_logic_vector(RAM_WIDTH-1 downto 0)   	  			-- RAM output data
);
end component;

component uart_rx is
generic(
c_clkfreq 	: integer := 100_000_000;
c_baudrate 	: integer := 9600
);
port(
clk 			: in std_logic;
rx_i 			: in std_logic;
dout_o 			: out std_logic_vector(7 downto 0);
rx_done_tick_o	: out std_logic
);
end component;

component uart_tx is
generic(
c_clkfreq 	: integer := 100_000_000;
c_baudrate 	: integer := 9600;
c_stopbit 	: integer := 2 
);
port(
clk 			: in std_logic;
din_i 			: in std_logic_vector (7 downto 0);
tx_start_i 		: in std_logic;
tx_o 			: out std_logic;
tx_done_tick_o 	: out std_logic
);
end component;

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------	
type t_state is (S_IDLE, S_READ, S_WRITE, S_TRANS);

--------------------------------------------------------------------------------
-- SIGNALS
--------------------------------------------------------------------------------
signal state        : t_state                                           := S_IDLE;

-- rx signals
signal dout 		: std_logic_vector (7 downto 0)                     := (others => '0');
signal rx_done_tick : std_logic                                         := '0';

-- tx signals
signal din      	: std_logic_vector (7 downto 0)                     := (others => '0');
signal tx_start     : std_logic                                         := '0';
signal tx_done_tick : std_logic                                         := '0';

-- bram signals
signal wea          : std_logic                                         := '0';
signal addr         : std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0)  := (others => '0');
signal dwrite       : std_logic_vector (RAM_WIDTH-1 downto 0)           := (others => '0');
signal dread        : std_logic_vector (RAM_WIDTH-1 downto 0)           := (others => '0');

signal data_package : std_logic_vector (4*8-1 downto 0)           		:= (others => '0');

signal cntr 		: integer range 0 to 7 								:= 0;
 
--------------------------------------------------------------------------------
-- BEGIN
--------------------------------------------------------------------------------	
begin

--------------------------------------------------------------------------------
-- COMPONENT INSTANTIATIONS
--------------------------------------------------------------------------------
i_uart_rx : uart_rx 
generic map(
c_clkfreq       => c_clkfreq,
c_baudrate      => c_baudrate
)
port map(
clk             	=> clk,
rx_i            	=> rx_i,
dout_o            	=> dout,
rx_done_tick_o    	=> rx_done_tick
);

i_uart_tx : uart_tx 
generic map(
c_clkfreq       => c_clkfreq,
c_baudrate      => c_baudrate,
c_stopbit       => 2
)
port map(
clk             	=> clk,
din_i           	=> din,
tx_start_i      	=> tx_start,
tx_o            	=> tx_o,
tx_done_tick_o     	=> tx_done_tick
);

i_block_ram : block_ram 
generic map(
RAM_WIDTH       	=> RAM_WIDTH,
RAM_DEPTH       	=> RAM_DEPTH,
RAM_PERFORMANCE 	=> RAM_PERFORMANCE  
)
port map(
addra  => addr,
dina   => dwrite,
clka   => clk,
wea    => wea,
douta  => dread
);

--------------------------------------------------------------------------------
-- PROCESS STATEMENTS 
-- NOTE: Process blocks work concurrently with each other
--------------------------------------------------------------------------------
-- SEQUENTIAL PROCESS
-- main process
P_MAIN : process(clk) begin
if(rising_edge(clk)) then
    
    case state is 
        when S_IDLE =>
			tx_start 	<= '0';
			wea 		<= '0';
            if(rx_done_tick = '1') then
                data_package	<= data_package(3*8-1 downto 0) & dout;
            end if; 
			
			if(data_package(8*4-1 downto 8*3) = x"0A") then
				state 			<= S_WRITE;
			end if;
			
			if(data_package(8*4-1 downto 8*3) = x"0B") then
				state 			<= S_READ;
			end if;
            
		when S_WRITE =>
			wea 				<= '1';
			addr 				<= data_package(8*2 + clogb2(RAM_DEPTH) - 1 downto 8*2);
            dwrite 				<= data_package(8*2-1 downto 0);
			state 				<= S_IDLE;
			data_package 		<= (others => '0');
			
        when S_READ =>
			addr 				<= data_package(8*2 + clogb2(RAM_DEPTH) - 1 downto 8*2);
			cntr 				<= cntr + 1;
			if (cntr = 2) then
				data_package(2*8-1 downto 0) 	<= dread;
				tx_start 						<= '1';
				din 							<= dread(2*8-1 downto 1*8);
				state 							<= S_TRANS;
			end if;
        
        when S_TRANS => 
			tx_start <= '0';
			if (tx_done_tick = '1') then    
				tx_start <= '1';
				din 	<= data_package(1*8-1 downto 8*0);
				cntr 	<= cntr + 1;                     
			end if;
			
			if (cntr = 4 and tx_done_tick = '1') then         
				state 			<= S_IDLE;
				data_package 	<= (others => '0');
				cntr 			<= 0;
				tx_start 		<= '0';
			end if;
			
    
    end case;
end if;
end process;

end Behavioral;
