library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library unisim;
	use unisim.vcomponents.all;

-- Standard DCM
-- Input
--   CLK_IN			system input clock 32Mhz
-- Outputs
--   O_CLK_40M		generated 32Mhz /4 *5 = 40Mhz clock
--   O_CLK_115200	generated 40Mhz / 346 = 115606 baud clock

-- *******************************************************************
-- * the intent was to clock this to max clock supported by FLASH    *
-- * which is 80Mhz but run into issues that need to be investigated *
-- * further, simulation shows it should work but in practice I get  *
-- * read errors, either I'm running too close to limits, PCB design *
-- * might not be high speed enough, etc so this is for now clocked  *
-- * at 40Mhz which in practice reads the FLASH without errors       *
-- * clock divisors are set to 32Mhz /4 *5 = 40Mhz                   *
-- *******************************************************************

entity clocks is
	port (
		CLK_IN			: in  std_logic;
		O_CLK_40M		: out std_logic;
		O_CLK_115200	: out std_logic
	);
end clocks ;

architecture RTL of clocks is

	signal clk_ref_ibuf		: std_logic;
	signal clk_dcm_op_0		: std_logic;
	signal clk_dcm_op_fx		: std_logic;
	signal clk_dcm_0_bufg	: std_logic;
	signal clk_dcm_fx_bufg	: std_logic;
	signal clk_divider		: std_logic := '0';
	signal counter				: std_logic_vector(7 downto 0) := (others => '0');

begin

	IBUFG0 : IBUFG port map (I=> CLK_IN,			O => clk_ref_ibuf);
	BUFG0  : BUFG  port map (I=> clk_dcm_op_0,	O => clk_dcm_0_bufg);
	BUFG1  : BUFG  port map (I=> clk_dcm_op_fx,	O => clk_dcm_fx_bufg);
	O_CLK_40M		<= clk_dcm_fx_bufg;
	O_CLK_115200	<= clk_divider;

	dcm_inst : DCM_SP
		generic map (
			DLL_FREQUENCY_MODE		=> "LOW",
			DUTY_CYCLE_CORRECTION	=> TRUE,
			CLKOUT_PHASE_SHIFT		=> "NONE",
			PHASE_SHIFT					=> 0,
			CLKFX_MULTIPLY				=> 5,	-- range 2 to 32
			CLKFX_DIVIDE				=> 4,	-- range 1 to 32
			CLKDV_DIVIDE				=> 2.0,
			STARTUP_WAIT				=> FALSE,
			CLKIN_PERIOD				=> 31.25
		)

		port map (
			CLKIN			=> clk_ref_ibuf,
			CLKFB			=> clk_dcm_0_bufg,
			DSSEN			=> '0',
			PSINCDEC		=> '0',
			PSEN			=> '0',
			PSCLK			=> '0',
			RST			=> '0',
			CLK0			=> clk_dcm_op_0,
			CLK90			=> open,
			CLK180		=> open,
			CLK270		=> open,
			CLK2X			=> open,
			CLK2X180		=> open,
			CLKDV			=> open,
			CLKFX			=> clk_dcm_op_fx,
			CLKFX180		=> open,
			LOCKED		=> open,
			PSDONE		=> open
		);

	-- 115200 baud clock 
	divider: process(clk_dcm_fx_bufg)
		begin
		if rising_edge(clk_dcm_fx_bufg) then
			if (counter = x"ad") then	    -- 40Mhz /2 /"0ad" = 115606.9
				clk_divider <= not clk_divider;
				counter <= (others => '0');
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;

end RTL;
