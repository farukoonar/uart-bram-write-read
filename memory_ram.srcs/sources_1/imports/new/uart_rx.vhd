--------------------------------------------------------------------------------
-- LIBRARY and PACKAGE DECLARATIONS
--------------------------------------------------------------------------------
-- standard package
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity uart_rx is
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
end uart_rx;

--------------------------------------------------------------------------------
-- ARCHITECTURE
-----------------------------------------------------------------------------
architecture Behavioral of uart_rx is

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
constant c_bittimerlim : integer := c_clkfreq/c_baudrate;

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------
type t_state is (S_IDLE, S_STOP, S_DATA, S_START);
signal state : t_state := S_IDLE;

--------------------------------------------------------------------------------
-- SIGNALS
--------------------------------------------------------------------------------
signal bittimer 	: integer range 0 to c_bittimerlim 		:= 0;
signal bitcntr 		: integer range 0 to 7 					:= 0;
signal shreg 		: std_logic_vector (7 downto 0) 		:= (others => '0');
signal sync_reg 	: std_logic_vector(1 downto 0)			:= (others => '1');
signal rx_i_sync	: std_logic 							:= '1';

--------------------------------------------------------------------------------
-- BEGIN
--------------------------------------------------------------------------------	
begin

--------------------------------------------------------------------------------
-- CONCURRENT STATEMENTS
--------------------------------------------------------------------------------
rx_i_sync <= sync_reg(1);

--------------------------------------------------------------------------------
-- PROCESS STATEMENTS 
-- NOTE: Process blocks work concurrently with each other
--------------------------------------------------------------------------------
-- SEQUENTIAL PROCESS
-- synchronizer
P_SYNC : process(clk) begin
if rising_edge(clk) then
	sync_reg(1) 	<= sync_reg(0);
	sync_reg(0)     <= rx_i;
end if;
end process;

-- main process
P_MAIN : process(clk) begin
if(rising_edge(clk)) then
    
    case state is 
        when S_IDLE =>
            rx_done_tick_o 		<= '0';
            if(rx_i_sync = '0') then
                state 			<= S_START;
            end if;
            
        when S_START =>
            if(bittimer = (c_bittimerlim/2) - 1) then
				bittimer 	<= 0;
				if(rx_i_sync = '0') then
					state 		<= S_DATA;
				else
					state 		<= S_IDLE;
				end if;
            else
                bittimer 		<= bittimer + 1;
            end if;
            
        when S_DATA =>
            if(bittimer = c_bittimerlim - 1) then
                bittimer 		<= 0;
                shreg 			<= rx_i_sync & shreg(7 downto 1); 
                if(bitcntr = 7) then
                    state 		<= S_STOP;
                    bitcntr 	<= 0;
                else            
                    bitcntr 	<= bitcntr + 1;
                end if;
            else
                bittimer 		<= bittimer + 1;
            end if;
        
        when S_STOP =>
            if(bittimer = c_bittimerlim - 1) then
				dout_o			<= shreg;
                rx_done_tick_o 	<= '1';
                bittimer 		<= 0;
                state 			<= S_IDLE;
            else
                bittimer 		<= bittimer + 1;
            end if;
    end case;
end if;
end process;

end Behavioral;
