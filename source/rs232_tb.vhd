--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:18:03 07/07/2011
-- Design Name:   
-- Module Name:   C:/Users/alex/workspace/spi/spi_rs232_tb.vhd
-- Project Name:  spi
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: SPI_RS232
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY spi_rs232_tb IS
END spi_rs232_tb;
 
ARCHITECTURE behavior OF spi_rs232_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT rs232
    PORT(
         rs232_rxd : OUT  std_logic;
         rs232_data : IN  std_logic_vector(7 downto 0);
         rs232_send : IN  std_logic;
         rs232_done : OUT  std_logic;
         rs232_clk : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal rs232_data : std_logic_vector(7 downto 0) := (others => '0');
   signal rs232_send : std_logic := '0';
   signal clk : std_logic := '0';

 	--Outputs
   signal rs232_rxd : std_logic;
   signal rs232_done : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: rs232 PORT MAP (
          rs232_rxd => rs232_rxd,
          rs232_data => rs232_data,
          rs232_send => rs232_send,
          rs232_done => rs232_done,
          rs232_clk => clk
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 
			rs232_data <= x"5a";
--      wait for clk_period;
			rs232_send <= '1';
      wait for clk_period*20;
			rs232_send <= '0';
      wait for clk_period;

			rs232_data <= x"a5";
--      wait for clk_period;
			rs232_send <= '1';
      wait for clk_period*20;
			rs232_send <= '0';
      wait for clk_period*2;

      wait;
   end process;

END;
