--
--	scio_lego.vhd
--
--	io devices for LEGO MindStorms
--
--
--	io address mapping:
--
--	IO Base is 0xffffff80 for 'fast' constants (bipush)
--
--		0x00 0-3		system clock counter, us counter, timer int, wd bit
--		0x10 0-1		uart (download)
--		0x30			LEGO interface
--
--	status word in uarts:
--		0	uart transmit data register empty
--		1	uart read data register full
--
--
--	todo:
--
--
--	2003-07-09	created
--	2005-08-27	ignore ncts on uart
--	2005-11-30	changed to SimpCon
--
--


library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.jop_types.all;
use work.jop_config.all;

entity scio is
generic (addr_bits : integer);

port (
	clk		: in std_logic;
	reset	: in std_logic;

-- SimpCon interface

	address		: in std_logic_vector(addr_bits-1 downto 0);
	wr_data		: in std_logic_vector(31 downto 0);
	rd, wr		: in std_logic;
	rd_data		: out std_logic_vector(31 downto 0);
	rdy_cnt		: out unsigned(1 downto 0);

-- interrupt

	irq			: out std_logic;
	irq_ena		: out std_logic;

-- serial interface

	txd			: out std_logic;
	rxd			: in std_logic;
	ncts		: in std_logic;
	nrts		: out std_logic;

-- watch dog

	wd			: out std_logic;

-- core i/o pins
	l			: inout std_logic_vector(20 downto 1);
	r			: inout std_logic_vector(20 downto 1);
	t			: inout std_logic_vector(6 downto 1);
	b			: inout std_logic_vector(10 downto 1)
);
end scio;


architecture rtl of scio is

	constant SLAVE_CNT : integer := 4;
	-- SLAVE_CNT <= 2**DECODE_BITS
	constant DECODE_BITS : integer := 2;
	-- number of bits that can be used inside the slave
	constant SLAVE_ADDR_BITS : integer := 4;

	type slave_bit is array(0 to SLAVE_CNT-1) of std_logic;
	signal sc_rd, sc_wr		: slave_bit;

	type slave_dout is array(0 to SLAVE_CNT-1) of std_logic_vector(31 downto 0);
	signal sc_dout			: slave_dout;

	type slave_rdy_cnt is array(0 to SLAVE_CNT-1) of unsigned(1 downto 0);
	signal sc_rdy_cnt		: slave_rdy_cnt;

	signal sel, sel_reg		: integer range 0 to 2**DECODE_BITS-1;

begin

--
--	unused and input pins tri state
--
	t(5 downto 4) <= (others => 'Z');
	l(17 downto 16) <= (others => 'Z');
	l(11 downto 9) <= (others => 'Z');
	l(7 downto 1) <= (others => 'Z');
	r(20 downto 13) <= (others => 'Z');
	r(11 downto 1) <= (others => 'Z');
	b <= (others => 'Z');

	assert SLAVE_CNT <= 2**DECODE_BITS report "Wrong constant in scio";

	sel <= to_integer(unsigned(address(SLAVE_ADDR_BITS+DECODE_BITS-1 downto SLAVE_ADDR_BITS)));

	-- What happens when sel_reg > SLAVE_CNT-1??
	rd_data <= sc_dout(sel_reg);
	rdy_cnt <= sc_rdy_cnt(sel_reg);

	--
	-- Connect SLAVE_CNT simple test slaves
	--
	gsl: for i in 0 to SLAVE_CNT-1 generate

		sc_rd(i) <= rd when i=sel else '0';
		sc_wr(i) <= wr when i=sel else '0';

	end generate;

	--
	--	Register read mux selector
	--
	process(clk, reset)
	begin
		if (reset='1') then
			sel_reg <= 0;
		elsif rising_edge(clk) then
			if rd='1' then
				sel_reg <= sel;
			end if;
		end if;
	end process;
			
	cmp_cnt: entity work.sc_cnt generic map (
			addr_bits => SLAVE_ADDR_BITS,
			clk_freq => clk_freq
		)
		port map(
			clk => clk,
			reset => reset,

			address => address(SLAVE_ADDR_BITS-1 downto 0),
			wr_data => wr_data,
			rd => sc_rd(0),
			wr => sc_wr(0),
			rd_data => sc_dout(0),
			rdy_cnt => sc_rdy_cnt(0),

			irq => irq,
			irq_ena => irq_ena,
			wd => wd
		);

	cmp_ua: entity work.sc_uart generic map (
			addr_bits => SLAVE_ADDR_BITS,
			clk_freq => clk_freq,
			baud_rate => 115200,
			txf_depth => 2,
			txf_thres => 1,
			rxf_depth => 2,
			rxf_thres => 1
		)
		port map(
			clk => clk,
			reset => reset,

			address => address(SLAVE_ADDR_BITS-1 downto 0),
			wr_data => wr_data,
			rd => sc_rd(1),
			wr => sc_wr(1),
			rd_data => sc_dout(1),
			rdy_cnt => sc_rdy_cnt(1),

			txd	 => txd,
			rxd	 => rxd,
			ncts => '0',
			nrts => nrts
	);

	-- slave 2 is reserved for USB and System.out writes to it!!!

	cmp_lego: entity work.sc_lego generic map (
			addr_bits => SLAVE_ADDR_BITS,
			clk_freq => clk_freq
		)
		port map(
			clk => clk,
			reset => reset,

			address => address(SLAVE_ADDR_BITS-1 downto 0),
			wr_data => wr_data,
			rd => sc_rd(3),
			wr => sc_wr(3),
			rd_data => sc_dout(3),
			rdy_cnt => sc_rdy_cnt(3),

			-- LEGO interface
			-- motor stuff
											-- schematics wire names:
			ma_en => l(14),					-- en1
			ma_l1 => l(15),					-- in1a
			ma_l2 => l(20),					-- in1b
			ma_l1_sdi => t(1),				-- sdi3
			ma_l1_sdo => r(12),				-- sdo3
			ma_l2_sdi => t(2),				-- sdi2
			ma_l2_sdo => l(8),				-- sdo2

			mb_en => l(19),					-- en2
			mb_l1 => l(13),					-- in2a
			mb_l2 => l(18),					-- in2b

			-- sensor stuff

			s1_pow => l(12),				-- sp1
			s1_sdi => t(3),					-- sdi1
			s1_sdo => t(6)					-- sdo1
		);

end rtl;
