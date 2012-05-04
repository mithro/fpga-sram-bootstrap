library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_textio.all;

library std;
	use std.textio.all;

library unisim;
	use unisim.vcomponents.all;

entity bootstrap_top_tb is
		generic(stim_file: string :="stim.txt");
end bootstrap_top_tb;
 
architecture behavior of bootstrap_top_tb is 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    component bootstrap_top
    port(
         FLASH_CS    : out std_logic;
         FLASH_SI    : out std_logic;
         FLASH_SO    : in  std_logic;
         FLASH_CK    : out std_logic;
         SRAM_A		: out	std_logic_vector(17 downto 0);
         SRAM_D		: inout	std_logic_vector(15 downto 0);
         SRAM_nCS		: out	std_logic;
         SRAM_nWE		: out	std_logic;
         SRAM_nOE		: out	std_logic;
         SRAM_nBE		: out	std_logic;
         USB_RXD     : out std_logic;
         RESET			: in	std_logic;
         CLK_IN      : in  std_logic
        );
    end component;

   --Inputs
   signal clock    : std_logic := '0';
   signal FLASH_SO : std_logic := '1';
   signal CLK_IN   : std_logic := '0';
   signal RESET    : std_logic := '0';

 	--Outputs
   signal FLASH_CS : std_logic;
   signal FLASH_SI : std_logic;
   signal FLASH_CK : std_logic;
   signal USB_RXD  : std_logic;

   signal SRAM_nCS : std_logic;
   signal SRAM_nWE : std_logic;
   signal SRAM_nOE : std_logic;
   signal SRAM_nBE : std_logic;
   signal SRAM_A : std_logic_vector(17 downto 0);
   signal SRAM_D : std_logic_vector(15 downto 0);

	file stimulus: TEXT open read_mode is stim_file;
	signal counter : std_logic_vector(5 downto 0) := (others => '0');
	constant clock_period : time := 31.25 ns;
begin
 
	-- Instantiate the unit under test (uut)
   uut: bootstrap_top port map (
	 FLASH_CS => FLASH_CS,
	 FLASH_SI => FLASH_SI,
	 FLASH_SO => FLASH_SO,
	 FLASH_CK => FLASH_CK,
	 SRAM_A	 => SRAM_A,
	 SRAM_D	 => SRAM_D,
	 SRAM_nCS => SRAM_nCS,
	 SRAM_nWE => SRAM_nWE,
	 SRAM_nOE => SRAM_nOE,
	 SRAM_nBE => SRAM_nBE,
	 RESET	 => RESET,
	 USB_RXD  => USB_RXD,
	 CLK_IN   => CLK_IN
  );
	CLK_IN <= clock;
   -- Clock process definitions
   clock_process :process
   begin
		clock <= '0';
		wait for clock_period/2;
		clock <= '1';
		wait for clock_period/2;
   end process;

	process(FLASH_CS, FLASH_CK)
	begin
		if FLASH_CS = '1' then
			counter <= (others => '0');
		elsif rising_edge(FLASH_CK) then
			if (counter <= "100111") then
				counter <= counter + 1;
			end if;
		end if;
	end process;

	-- Stimulus process
   stim_proc: process(FLASH_CK)
		variable inline:line;
		variable bv:std_logic_vector(7 downto 0) := (others => '0');
		variable i :std_logic_vector(2 downto 0) := (others => '0');
   begin		
		if not endfile(stimulus) then
			if falling_edge(FLASH_CK) and (counter > "100111") then 
				if i="000" then
					readline(stimulus, inline);
					hread(inline, bv);
				end if;
				i := i - 1;
				FLASH_SO <= bv(conv_integer(i));
			end if;
		else
			FLASH_SO <= '1';
		end if;
   end process;

	main : process
	begin
		RESET <= '1';
		wait for 30*clock_period;
		RESET <= '0';
		wait;
   end process;

end;
