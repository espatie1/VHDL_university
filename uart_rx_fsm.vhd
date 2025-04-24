-- uart_rx_fsm.vhd: UART controller - finite state machine controlling RX side
-- Author(s): Name Surname (xstepa77)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;



entity UART_RX_FSM is
    port(
    -- INPUTS
        CLK             : in std_logic;  -- CLK
        RST             : in std_logic;  -- RST
        DIN_FSM         : in std_logic;  -- standart DIN
        BIT_END         : in std_logic;  -- BIT_END, Middle of bit
        WORD_END        : in std_logic;  -- WORD_END, End of a 10-bit word (start bit + 8 data bits + stop bit)
    -- OUTPUTS
        START_DATA_READ : out std_logic; -- If active, start reading data from DIN
        START_BIT_FSM   : out std_logic; -- If active, start reading start bit
        TIME_CNT        : out std_logic; -- Start counting time
        VALID           : out std_logic; -- Active when word is readen and ready to be processed
        RESET           : out std_logic  -- Resets the DEMUX_OUT
    );
end entity;



architecture behavioral of UART_RX_FSM is


type t_state is (IDLE, START_BIT_STATE, DATA_BITS_STATE, STOP_BIT_STATE);
signal state : t_state;
signal next_state : t_state;

begin

    -- PRESENT STATE
    PRESENT_STATE: process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                state <= IDLE;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    -- NEXT STATE COMBINATORIAL LOGIC
    NEXT_STATE_LOGIC: process(state, DIN_FSM, BIT_END, WORD_END)
    begin
        next_state <= state; -- If nothing happens, stay in the same state
        case state is

            when IDLE =>                -- IDLE state. When program just waits for start bit
                if (DIN_FSM = '0') then -- Detect start bit = '0'
                    next_state <= START_BIT_STATE; 
                end if;

            when START_BIT_STATE =>     -- State when start bit is readen
                if BIT_END = '1' then   -- When middle bit of start bit is readen
                    next_state <= DATA_BITS_STATE;
                end if;

            when DATA_BITS_STATE =>     -- State when data bits and stop bit are readen
                if (BIT_END = '1' and WORD_END = '1') then -- When middle bit of stop bit is readen
                    next_state <= STOP_BIT_STATE;
                end if;

            when STOP_BIT_STATE =>
                if BIT_END = '1' then   -- When 16 CLK cycles (= 1 BIT_END) are passed
                    next_state <= IDLE;
                end if;

        end case;
    end process;

    -- OUTPUT LOGIC
    OUTPUT_LOGIC: process(state)
    begin
        -- STANDARD OUTPUTS
        START_BIT_FSM     <= '0'; 
        START_DATA_READ   <= '0';
        VALID             <= '0';
        TIME_CNT          <= '1'; 
        RESET             <= '0';

        case state is

            when IDLE =>
                TIME_CNT        <= '0'; -- Stop counting time
                RESET           <= '1'; -- Reset the DEMUX_OUT. Just for a better visualization
            when START_BIT_STATE =>
                START_DATA_READ <= '1'; -- Start reading data from DIN
                START_BIT_FSM   <= '1'; -- Start reading start bit
            when DATA_BITS_STATE =>
                START_DATA_READ <= '1'; -- Still reading data from DIN
            when STOP_BIT_STATE =>
                VALID           <= '1'; -- Word is readen and ready to be processed

        end case;
    end process;
end architecture;
