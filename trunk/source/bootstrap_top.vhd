library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library unisim;
	use unisim.vcomponents.all;

entity bootstrap_top is
	port(
		FLASH_CS		: out		std_logic;								-- Active low FLASH chip select
		FLASH_SI		: out		std_logic;								-- Serial output to FLASH chip SI pin
		FLASH_CK		: out		std_logic;								-- FLASH clock
		FLASH_SO		: in		std_logic := '0';						-- Serial input from FLASH chip SO pin
		--
		SRAM_A		: out		std_logic_vector(17 downto 0);	-- SRAM address bus
		SRAM_D		: inout	std_logic_vector(15 downto 0);	-- SRAM data bus
		SRAM_nCS		: out		std_logic;								-- SRAM chip select active low
		SRAM_nWE		: out		std_logic;								-- SRAM write enable active low
		SRAM_nOE		: out		std_logic;								-- SRAM output enable active low
		SRAM_nBE		: out		std_logic;								-- SRAM byte enables active low
		--
		USB_RXD		: out		std_logic;								-- output RS232 data stream 8N1
		--
		RESET			: in		std_logic := '0';						-- Active high external reset
		CLK_IN		: in		std_logic := '0'						-- System clock 32Mhz
	);
end bootstrap_top;

architecture RTL of bootstrap_top is
	-- start address of user data in FLASH as obtained from bitmerge.py
	constant user_address	: std_logic_vector(23 downto 0) := x"05327C";
	-- user_length = "max FLASH addr" - user_address = 7FFFF - 5327C = 2CD83
	constant user_length		: std_logic_vector(23 downto 0) := x"02CD83";

	--
	-- bootstrap signals
	--
	signal hex					: std_logic_vector( 3 downto 0) := (others => '0');
	signal asc					: std_logic_vector( 7 downto 0) := (others => '0');
	signal flash_data			: std_logic_vector( 7 downto 0) := (others => '0');
	signal crlf_count			: std_logic_vector( 3 downto 0) := (others => '0');
	signal rs232_data			: std_logic_vector( 7 downto 0) := (others => '0');
	signal rs232_send			: std_logic := '0';
	signal rs232_Done			: std_logic := '0';

	-- bootstrap control of SRAM, these signals connect to SRAM when boostrap_busy = '1'
	signal bs_A					: std_logic_vector(17 downto 0) := (others => '0');
	signal bs_Din				: std_logic_vector(15 downto 0) := (others => '0');
	signal bs_Dout				: std_logic_vector(15 downto 0) := (others => '0');
	signal bs_nCS				: std_logic := '0';
	signal bs_nWE				: std_logic := '0';
	signal bs_nOE				: std_logic := '1';

	signal flash_init			: std_logic := '0';	-- when low places FLASH driver in init state
	signal bootstrap_busy	: std_logic := '0';	-- high when FLASH is being copied to SRAM, can be used by user as active high reset
	signal flash_Done			: std_logic := '0';	-- FLASH init finished when high
	signal clk_40M				: std_logic := '0';	-- main system clock

	-- for bootstrap state machine
	type	BS_STATE_TYPE is (
				INIT, START_READ_FLASH, READ_FLASH, FLASH0, FLASH1, FLASH2, FLASH3, FLASH4, FLASH5, FLASH6, FLASH7,
				WAIT0, WAIT1, WAIT2, WAIT3, WAIT4, WAIT5, WAIT6, WAIT7, WAIT8, WAIT9, WAIT10, WAIT11
			);
	signal bs_state, bs_state_next : BS_STATE_TYPE;

	--
	-- user signals
	--

	-- user control of SRAM, these signals connect to SRAM when boostrap_busy = '0'
	signal user_A				: std_logic_vector(17 downto 0) := (others => '0');
	signal user_Din			: std_logic_vector(15 downto 0) := (others => '0');
	signal user_Dout			: std_logic_vector(15 downto 0) := (others => '0');
	signal user_nCS			: std_logic := '0';
	signal user_nWE			: std_logic := '1';
	signal user_nOE			: std_logic := '0';

	signal clk_115200			: std_logic := '0';	-- baud clock

	-- for user state machine
	type	U_STATE_TYPE is (
				INIT, START_READ_SRAM, READ_SRAM, START_WRITE_RS232_CR, START_WRITE_RS232_DH, START_WRITE_RS232_DL,
				START_WRITE_RS232_LF, START_WRITE_RS232_SP, WRITE_RS232_CR, WRITE_RS232_DH, WRITE_RS232_DL, WRITE_RS232_LF, WRITE_RS232_SP
			);
	signal u_state, u_state_next : U_STATE_TYPE;

begin
	-- clock DCM
	u_clocks : entity work.clocks
	port map (
		CLK_IN			=> CLK_IN,
		O_CLK_40M		=> clk_40M,
		O_CLK_115200	=> clk_115200
	);

	-- FLASH chip SPI driver
	u_flash : entity work.spi_flash
	port map (
		U_FLASH_CK => FLASH_CK,
		U_FLASH_CS => FLASH_CS,
		U_FLASH_SI => FLASH_SI,
		U_FLASH_SO => FLASH_SO,
		flash_addr => user_address,
		flash_data => flash_data,
		flash_init => flash_init,
		flash_Done => flash_Done,
		flash_clk  => clk_40M
	);

	-- RS232 driver
	u_rs232 : entity work.rs232
	port map (
		rs232_rxd	=> USB_RXD,
		rs232_data	=> rs232_data,
		rs232_send	=> rs232_send,
		rs232_Done	=> rs232_Done,
		rs232_clk	=> clk_115200
	);

	-- SRAM muxer, allows access to physical SRAM by either bootstrap or user
	SRAM_D		<= bs_Dout when bootstrap_busy = '1' and bs_nWE = '0' else user_Dout when bootstrap_busy = '0' and bs_nWE = '0' else (others => 'Z');
	SRAM_A		<= bs_A    when bootstrap_busy = '1' else user_A;
	SRAM_nCS		<= bs_nCS  when bootstrap_busy = '1' else user_nCS;
	SRAM_nWE		<= bs_nWE  when bootstrap_busy = '1' else user_nWE;
	SRAM_nOE		<= bs_nOE  when bootstrap_busy = '1' else user_nOE;

	SRAM_nBE		<= '0'; -- nUB and nLB tied together, SRAM always in 16 bit mode, grrr!
	user_Din		<= SRAM_D; -- anyone can read SRAM_D without contention but his provides some logical separation
	bs_Din		<= SRAM_D;

	-- bootstrap state machine
	state_bootstrap : process(clk_40M, RESET, bs_state_next)
	begin
		bs_state <= bs_state_next;									-- advance bootstrap state machine
		if RESET = '1' then											-- external reset pin
			bs_state_next <= INIT;									-- move state machine to INIT state
		elsif rising_edge(clk_40M) then
			case bs_state is
				when INIT =>
					bootstrap_busy <= '1';							-- indicate bootstrap in progress (holds user in reset)
					flash_init <= '0';								-- signal FLASH to begin init
					bs_Dout(15 downto 8) <= (others => '0');	-- SRAM high data bus not used during bootstrap
					bs_A   <= (others => '1');						-- SRAM address all ones (becomes zero on first increment)
					bs_nCS <= '0';										-- SRAM always selected during bootstrap
					bs_nOE <= '1';										-- SRAM output disabled during bootstrap
					bs_nWE <= '1';										-- SRAM write enable inactive default state
					bs_state_next <= START_READ_FLASH;
				when START_READ_FLASH =>
					flash_init <= '1';								-- allow FLASH to exit init state
					if flash_Done = '0' then						-- wait for FLASH init to begin
						bs_state_next <= READ_FLASH;
					end if;
				when READ_FLASH =>
					if flash_Done = '1' then						-- wait for FLASH init to complete
						bs_state_next <= WAIT0;
					end if;
				when WAIT0 =>											-- wait for the first FLASH byte to be available
					bs_state_next <= WAIT1;
				when WAIT1 =>
					bs_state_next <= WAIT2;
				when WAIT2 =>
					bs_state_next <= WAIT3;
				when WAIT3 =>
					bs_state_next <= WAIT4;
				when WAIT4 =>
					bs_state_next <= WAIT5;
				when WAIT5 =>
					bs_state_next <= WAIT6;
				when WAIT6 =>
					bs_state_next <= WAIT7;
				when WAIT7 =>
					bs_state_next <= WAIT8;
				when WAIT8 =>
					bs_state_next <= FLASH0;

				when WAIT9 =>
					bs_state_next <= WAIT10;
				when WAIT10 =>
					bs_state_next <= WAIT11;
				when WAIT11 =>
					bs_state_next <= FLASH0;

				-- every 8 clock cycles (32M/8 = 2Mhz) we have a new byte from FLASH
				-- use this ample time to write it to SRAM, we just have to toggle nWE
				when FLASH0 =>
					bs_A <= bs_A + 1;									-- increment SRAM address
					bs_state_next <= FLASH1;						-- idle
				when FLASH1 =>
					bs_Dout( 7 downto 0) <= flash_data;			-- place byte on SRAM data bus
					bs_state_next <= FLASH2;						-- idle
				when FLASH2 =>
					bs_nWE <= '0';										-- SRAM write enable
					bs_state_next <= FLASH3;
				when FLASH3 =>
					bs_state_next <= FLASH4;						-- idle
				when FLASH4 =>
					bs_state_next <= FLASH5;						-- idle
				when FLASH5 =>
					bs_state_next <= FLASH6;						-- idle
				when FLASH6 =>
					bs_nWE <= '1';										-- SRAM write disable
					bs_state_next <= FLASH7;
				when FLASH7 =>
					if bs_A = user_length then						-- when we've reached end address
						bootstrap_busy <= '0';						-- indicate bootsrap is done
						flash_init <= '0';							-- place FLASH in init state
						bs_state_next <= FLASH7;					-- remain in this state until reset
					else
						bs_state_next <= FLASH0;					-- else loop back
					end if;
				when others =>											-- catch all, never reached
					bs_state_next <= INIT;
			end case;

		end if;
	end process;

------------------------------------------------------------------------------
-- SRAM Bootstrap is now finished
-- Example user code below can be activated by using bootstrap_busy as a reset signal
-- We will now read the SRAM contents and send them out via the RS232 serial output at
-- 115200 8N1 or insert your own code here to use the SRAM and its contents as you wish
------------------------------------------------------------------------------
	-- Hex to ASCII lookup table
	process(hex)
	begin
		case hex is
			when x"0" => asc <= x"30";	-- ASCII '0'
			when x"1" => asc <= x"31";	-- ...
			when x"2" => asc <= x"32";
			when x"3" => asc <= x"33";
			when x"4" => asc <= x"34";
			when x"5" => asc <= x"35";
			when x"6" => asc <= x"36";
			when x"7" => asc <= x"37";
			when x"8" => asc <= x"38";
			when x"9" => asc <= x"39";
			when x"a" => asc <= x"41";	-- ASCII 'A'
			when x"b" => asc <= x"42";	-- ...
			when x"c" => asc <= x"43";
			when x"d" => asc <= x"44";
			when x"e" => asc <= x"45";
			when x"f" => asc <= x"46";
			when others => asc <= x"20";	-- ASCII space (catch all, never reached)
		end case;
	end process;

	state_user : process(clk_115200, u_state_next)
	begin
		u_state  <= u_state_next;									-- advance user state machine
		if falling_edge(clk_115200) then
			if bootstrap_busy = '1' then							-- user reset signal active
				u_state_next <= INIT;
			else
				case u_state is
					when INIT =>
						user_A   <= (others => '1');				-- SRAM address all ones (becomes zero on first increment)
						user_nCS <= '0';								-- SRAM always selected
						user_nOE <= '0';								-- SRAM output enabled
						user_nWE <= '1';								-- SRAM write enable inactive default state
						rs232_send <= '0';							-- clear RS232 send
						crlf_count <= (others => '0');			-- counter to send CR/LF every 16 bytes
						u_state_next <= START_READ_SRAM;

					when START_READ_SRAM =>
						if user_A /= user_length then				-- stop here when contents of SRAM have been sent
							user_A  <= user_A + 1;					-- increment SRAM address
							u_state_next <= READ_SRAM;
						end if;

					when READ_SRAM =>
						hex <= user_Din(7 downto 4);				-- convert top nibble of byte to ASCII
						u_state_next <= START_WRITE_RS232_DH;

					when START_WRITE_RS232_DH =>
						rs232_data <= asc;							-- place ASCII value to send
						rs232_send <= '1';							-- activate RS232 driver
						u_state_next <= WRITE_RS232_DH;

					when WRITE_RS232_DH =>
						if rs232_Done = '1' then					-- when RS232 send is complete
							rs232_send <= '0';						-- deactivate RS232 driver (resets driver state)
							hex <= user_Din(3 downto 0);			-- convert low byte nibble to ASCII
							u_state_next <= START_WRITE_RS232_DL;
						end if;

					when START_WRITE_RS232_DL =>					-- repeat RS232 send process
						rs232_data <= asc;
						rs232_send <= '1';
						u_state_next <= WRITE_RS232_DL;

					when WRITE_RS232_DL =>
						if rs232_Done = '1' then
							rs232_send <= '0';
							crlf_count <= crlf_count + 1;
							if crlf_count = "1111" then			-- is it time to send CR/LF?
								u_state_next <= START_WRITE_RS232_CR;
							else
								u_state_next <= START_WRITE_RS232_SP;
							end if;
						end if;

					when START_WRITE_RS232_SP =>
						rs232_send <= '1';
						rs232_data <= x"20";							-- send a space after each byte
						u_state_next <= WRITE_RS232_SP;
					when WRITE_RS232_SP =>
						if rs232_Done = '1' then
							rs232_send <= '0';
							u_state_next <= START_READ_SRAM;		-- loop back for more
						end if;

					when START_WRITE_RS232_CR =>
						rs232_send <= '1';
						rs232_data <= x"0D";							-- send a carriage return after every 16 bytes
						u_state_next <= WRITE_RS232_CR;
					when WRITE_RS232_CR =>
						if rs232_Done = '1' then
							rs232_send <= '0';
							u_state_next <= START_WRITE_RS232_LF;	-- loop back for more
						end if;

					when START_WRITE_RS232_LF =>
						rs232_send <= '1';
						rs232_data <= x"0A";							-- send a line feed after every 16 bytes
						u_state_next <= WRITE_RS232_LF;
					when WRITE_RS232_LF =>
						if rs232_Done = '1' then
							rs232_send <= '0';
							u_state_next <= START_READ_SRAM;		-- loop back for more
						end if;

					when others =>										-- catch all, never reached
						u_state_next <= INIT;
				end case;
			end if;
		end if;
	end process;
end RTL;
