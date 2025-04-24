-- uart_rx.vhd: UART controller - receiving (RX) side
-- Author(s): Name Surname (xstepa77)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;



-- Entity declaration (DO NOT ALTER THIS PART!)
entity UART_RX is
    port(
        CLK      : in std_logic;
        RST      : in std_logic;
        DIN      : in std_logic;
        DOUT     : out std_logic_vector(7 downto 0);
        DOUT_VLD : out std_logic
    );
end entity;



-- Architecture implementation (INSERT YOUR IMPLEMENTATION HERE)
architecture behavioral of UART_RX is

signal CYCLE_CNT        : std_logic_vector(4-1 downto 0); -- 4 bits for 16 cycles of CLK
signal BIT_END          : std_logic;                      -- 1 middle bit (= 16 cycles of CLK)
signal DATA_CNT         : std_logic_vector(4-1 downto 0); -- 4 bits for start bit, 8 bits of data and stop bit
signal START_DATA_READ  : std_logic;                      -- If active, start reading data
signal WORD_END         : std_logic;                      -- End of a 10-bit word (start bit + 8 data bits + stop bit)
signal START_BIT_FSM    : std_logic;                      -- If active, start reading start bit
signal TIME_CNT         : std_logic;                      -- Start counting cycles of CLK
signal VALID            : std_logic;                      -- Active when word is readen and ready to be processed
signal RESET            : std_logic;                      -- Resets the DEMUX_OUT (sets it to "00000000")

begin
    -- Instance of RX FSM
    fsm: entity work.UART_RX_FSM
    port map ( -- Ports (No different from the FSM)
        CLK             => CLK,
        RST             => RST,
        START_DATA_READ => START_DATA_READ,
        START_BIT_FSM   => START_BIT_FSM,
        TIME_CNT        => TIME_CNT,
        DIN_FSM         => DIN,
        BIT_END         => BIT_END,
        WORD_END        => WORD_END,
        VALID           => VALID,
        RESET           => RESET
    );
    DOUT_VLD <= VALID and BIT_END; -- DOUT == VALID, but is should be valid only for 1 cycle of CLK, so the best way to implement this is using 'and BIT_END'

    DEMUX_OUT: process(CLK, RST, DATA_CNT, DIN) begin -- Demultiplexer for DOUT
        if (RESET = '1' or RST = '1') then -- Reset the DOUT
            DOUT <= "00000000";
        elsif rising_edge(CLK) then
            if (BIT_END = '1' and START_DATA_READ = '1' and WORD_END = '0') then 
                -- Reads only if it is a middle bit (BIT_END = '1') and if it 
                -- is reading data (START_DATA_READ = '1') and if it is 
                -- not a end of a word (WORD_END = '0')
                case DATA_CNT is 
                    when "0001" => DOUT(0) <= DIN;    -- Startes reading from "0001" because "0000" is the start bit
                    when "0010" => DOUT(1) <= DIN;
                    when "0011" => DOUT(2) <= DIN;
                    when "0100" => DOUT(3) <= DIN;
                    when "0101" => DOUT(4) <= DIN;
                    when "0110" => DOUT(5) <= DIN;
                    when "0111" => DOUT(6) <= DIN;
                    when "1000" => DOUT(7) <= DIN;
                    when others => null;
                end case;
            end if;
        end if;
    end process DEMUX_OUT;


    CYCLE_COUNT: process (CLK) begin -- Process for counting 16 or 8 cycles of CLK
        if (rising_edge(CLK)) then
            if(TIME_CNT = '1') then  -- Checks if it is time to count cycles of CLK
                CYCLE_CNT <= CYCLE_CNT + 1; 
            else 
                CYCLE_CNT <= "0000";
            end if;
            if (BIT_END = '1' and START_BIT_FSM = '1') then 
            -- If it is a middle bit, it drops "0111" to "0000" to start counting cycles of 16 CLK
                CYCLE_CNT <= "0000";
            end if;
        end if;
    end process;
    -- We get to the middle bit if we count 16 cycles of CLK or 8 cycles of CLK if we are reading the start bit
    BIT_END <= '1' when CYCLE_CNT = "1111" or (CYCLE_CNT = "0111" and START_BIT_FSM = '1') else '0'; 



    DATA_COUNT: process (CLK) begin         -- Process for counting 10 bits (start bit, 8 data bits and stop bit)
        if (rising_edge(CLK)) then
            if(START_DATA_READ = '1') then  -- Checks if it is time to read data
                if (BIT_END = '1') then     -- Checks if it is a middle bit
                    DATA_CNT <= DATA_CNT + 1;
                end if;
            else
                DATA_CNT <= (others => '0');
            end if;
        end if;
    end process;
    -- We get to the end of a word if we count 10 bits
    WORD_END <= '1' when DATA_CNT = "1001" else '0';

end architecture;
