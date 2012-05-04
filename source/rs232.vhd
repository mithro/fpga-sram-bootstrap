library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.STD_LOGIC_ARITH.ALL;
	use IEEE.STD_LOGIC_UNSIGNED.ALL;
	use IEEE.NUMERIC_STD.ALL;

library UNISIM;
	use UNISIM.VComponents.all;

-- Minimalistic RS232 transmit module 8N1
-- Inputs:
--   rs232_send	active high to start send data, must only go low after rs232_done goes high
--   rs232_data	byte to send
--   rs232_clk		clock at the required baud rate
-- Outputs
--   rs232_rxd		serial data stream out
--   rs232_done	goes high when ready to accept new data in

entity rs232 is
	port (
		rs232_rxd	: out	std_logic;
		rs232_data	: in  std_logic_vector (7 downto 0) := x"11";
		rs232_send	: in	std_logic := '0';
		rs232_done	: out	std_logic := '0';
		rs232_clk	: in	std_logic := '0'
	);
end rs232;

architecture RTL of rs232 is
	signal shift			: std_logic_vector(9 downto 0)  := (others => '1');
	signal tx_counter		: std_logic_vector(3 downto 0)  := (others => '0');

begin
	-- move state machine from state to state
	step_state : process(rs232_clk, rs232_send)
	begin
		-- initial state
		if rs232_send = '0' then
			tx_counter <= (others => '0');
		else
		-- advance state
			if rising_edge(rs232_clk) then
				if tx_counter /= "1111" then
					tx_counter <= tx_counter + '1';
				end if;
			end if;
		end if;
	end process;

	-- clock byte out serially
	send_byte : process(rs232_clk)
	begin
		if falling_edge(rs232_clk) then
			case tx_counter is
				when "0000" =>
					-- load stop bit + data + start bit
					shift <= '1' & rs232_data & '0';
					rs232_done <= '0';
				when "1010" =>
					rs232_done <= '1';
				when others =>
					-- shift data out left to right
					shift(9 downto 0) <= '1' & shift(9 downto 1) ;
			end case;
		end if;
	end process;

	rs232_rxd <= shift(0) or not rs232_send;

end RTL;
