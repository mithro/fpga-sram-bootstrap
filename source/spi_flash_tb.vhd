--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   21:53:49 07/05/2011
-- Design Name:   
-- Module Name:   C:/Users/alex/workspace/spi/u_flash_tb.vhd
-- Project Name:  spi
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: SPI_FLASH
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
 
ENTITY spi_flash_tb IS
END spi_flash_tb;
 
ARCHITECTURE behavior OF spi_flash_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT SPI_FLASH
    PORT(
         U_FLASH_CK : OUT  std_logic;
         U_FLASH_CS : OUT  std_logic;
         U_FLASH_SI : OUT  std_logic;
         U_FLASH_SO : IN  std_logic;
         flash_clk : IN  std_logic;
         flash_init : IN  std_logic;
         flash_addr : IN  std_logic_vector(23 downto 0);
         flash_data : OUT  std_logic_vector(7 downto 0);
         flash_done : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal U_FLASH_SO : std_logic := '0';
   signal flash_clk : std_logic := '0';
   signal flash_init : std_logic := '0';
   signal flash_addr : std_logic_vector(23 downto 0) := (others => '0');

 	--Outputs
   signal U_FLASH_CK : std_logic;
   signal U_FLASH_CS : std_logic;
   signal U_FLASH_SI : std_logic;
   signal flash_data : std_logic_vector(7 downto 0);
   signal flash_done : std_logic;

   -- Clock period definitions
   constant flash_clk_period : time := 12.5 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: SPI_FLASH PORT MAP (
          U_FLASH_CK => U_FLASH_CK,
          U_FLASH_CS => U_FLASH_CS,
          U_FLASH_SI => U_FLASH_SI,
          U_FLASH_SO => U_FLASH_SO,
          flash_clk => flash_clk,
          flash_init => flash_init,
          flash_addr => flash_addr,
          flash_data => flash_data,
          flash_done => flash_done
        );

   -- Clock process definitions
   flash_clk_process :process
   begin
		flash_clk <= '0';
		wait for flash_clk_period/2;
		flash_clk <= '1';
		wait for flash_clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		

		wait until rising_edge(flash_clk);

		flash_addr <= x"c0ffee";

		wait until rising_edge(flash_clk);

		flash_init <= '1';
		U_FLASH_SO <= '1';
      wait;
   end process;

END;
