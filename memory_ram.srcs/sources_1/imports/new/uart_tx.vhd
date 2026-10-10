--------------------------------------------------------------------------------
-- LIBRARY and PACKAGE DECLARATIONS
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity uart_tx is
generic(
c_clkfreq 	: integer := 100_000_000;
c_baudrate 	: integer := 9600;
c_stopbit 	: integer := 2 
);
port(
clk 			: in std_logic;
din_i 			: in std_logic_vector (7 downto 0);
tx_start_i 		: in std_logic ;
tx_o 			: out std_logic ;
tx_done_tick_o 	: out std_logic 
);
end uart_tx;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of uart_tx is

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
constant c_bittimer_lim : integer range 0 to c_clkfreq/c_baudrate 		:= c_clkfreq/c_baudrate;
constant c_stopbit_lim 	: integer range 0 to c_bittimer_lim *c_stopbit 	:= c_bittimer_lim *c_stopbit;

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------
type t_state is (S_IDLE, S_STOP, S_DATA, S_START);
signal state : t_state := S_IDLE;

--------------------------------------------------------------------------------
-- SIGNALS
--------------------------------------------------------------------------------
signal bittimer : integer range 0 to c_stopbit_lim 	:= 0;
signal bitcntr 	: integer range 0 to 7 				:= 0;
signal shreg 	: std_logic_vector(7 downto 0) 		:= (others => '0');

--------------------------------------------------------------------------------
-- BEGIN
--------------------------------------------------------------------------------	
begin

P_STATE : process(clk) begin
if(rising_edge(CLK)) then
    case state is
        when S_IDLE =>
            tx_o 				<= '1';
            tx_done_tick_o 		<= '0';
            
            if(tx_start_i = '1') then
                shreg 			<= din_i;
                state 			<= S_START;
                bittimer 		<= 0;
				tx_o 			<= '0';
            end if;
            
        when S_START =>
            
            if (bittimer = c_bittimer_lim - 1) then
                state 			<= S_DATA;  
                bitcntr 		<= 0;
                bittimer 		<= 0;
                tx_o 			<= shreg(0);   
            else
                bittimer 		<= bittimer + 1;         
            end if;
                
        when S_DATA =>
            
            if(bittimer = c_bittimer_lim - 1) then
                if (bitcntr = 7) then 
					tx_o 		<= '1';
                    state 		<= S_STOP;
                    bittimer 	<= 0;
					bitcntr 	<= 0;
                else  
					shreg 		<= '0' & shreg(7 downto 1);
                    tx_o 		<= shreg(1);
                    bitcntr 	<= bitcntr + 1;
                    bittimer 	<= 0;
                end if;
            else
                bittimer 		<= bittimer + 1;
            end if;
            
        when S_STOP =>
            if (bittimer = c_stopbit_lim - 1) then
                tx_done_tick_o 	<= '1';
                state 			<= S_IDLE;  
                bittimer 		<= 0;
            else 
                bittimer 		<= bittimer + 1;
            end if;
     
    end case;
end if;
end process;

end Behavioral;
