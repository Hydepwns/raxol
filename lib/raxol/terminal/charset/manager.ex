defmodule Raxol.Terminal.Charset.Manager do
  @moduledoc """
  Manages terminal character sets and encoding operations.
  """

  defstruct g_sets: %{
              g0: :us_ascii,
              g1: :us_ascii,
              g2: :us_ascii,
              g3: :us_ascii
            },
            current_g_set: :g0,
            single_shift: nil,
            charsets: %{
              us_ascii: &__MODULE__.us_ascii_map/0,
              dec_supplementary: &__MODULE__.dec_supplementary_map/0,
              dec_special: &__MODULE__.dec_special_map/0,
              dec_technical: &__MODULE__.dec_technical_map/0
            }

  @type g_set :: :g0 | :g1 | :g2 | :g3
  @type charset ::
          :us_ascii | :dec_supplementary | :dec_special | :dec_technical
  @type char_map :: %{non_neg_integer() => String.t()}

  @type t :: %__MODULE__{
          g_sets: %{g_set() => charset()},
          current_g_set: g_set(),
          single_shift: g_set() | nil,
          charsets: %{charset() => (-> char_map())}
        }

  @doc """
  Creates a new charset manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current state of the charset manager.
  """
  def get_state(%__MODULE__{} = state) do
    state
  end

  @doc """
  Updates the state of the charset manager.
  """
  def update_state(%__MODULE__{} = state, new_state) when is_map(new_state) do
    Map.merge(state, new_state)
  end

  @doc """
  Designates a character set for a specific G-set.
  """
  def designate_charset(%__MODULE__{} = state, g_set, charset)
      when g_set in [:g0, :g1, :g2, :g3] and
             charset in [
               :us_ascii,
               :dec_supplementary,
               :dec_special,
               :dec_technical
             ] do
    %{state | g_sets: Map.put(state.g_sets, g_set, charset)}
  end

  @doc """
  Invokes a G-set as the current character set.
  """
  def invoke_g_set(%__MODULE__{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    %{state | current_g_set: g_set}
  end

  @doc """
  Gets the current G-set.
  """
  def get_current_g_set(%__MODULE__{} = state) do
    state.current_g_set
  end

  @doc """
  Gets the designated charset for a G-set.
  """
  def get_designated_charset(%__MODULE__{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    Map.get(state.g_sets, g_set)
  end

  @doc """
  Resets the charset state to defaults.
  """
  def reset_state(%__MODULE__{} = state) do
    %{
      state
      | g_sets: %{
          g0: :us_ascii,
          g1: :us_ascii,
          g2: :us_ascii,
          g3: :us_ascii
        },
        current_g_set: :g0,
        single_shift: nil
    }
  end

  @doc """
  Applies a single shift to the current character.
  """
  def apply_single_shift(%__MODULE__{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    %{state | single_shift: g_set}
  end

  @doc """
  Gets the current single shift.
  """
  def get_single_shift(%__MODULE__{} = state) do
    state.single_shift
  end

  @doc """
  Returns the US ASCII character map.
  """
  def us_ascii_map do
    %{
      # Basic ASCII characters
      32 => " ",  # Space
      33 => "!",  # Exclamation mark
      34 => "\"", # Double quote
      35 => "#",  # Hash
      36 => "$",  # Dollar sign
      37 => "%",  # Percent
      38 => "&",  # Ampersand
      39 => "'",  # Single quote
      40 => "(",  # Left parenthesis
      41 => ")",  # Right parenthesis
      42 => "*",  # Asterisk
      43 => "+",  # Plus
      44 => ",",  # Comma
      45 => "-",  # Hyphen
      46 => ".",  # Period
      47 => "/",  # Forward slash
      48 => "0",  # Zero
      49 => "1",  # One
      50 => "2",  # Two
      51 => "3",  # Three
      52 => "4",  # Four
      53 => "5",  # Five
      54 => "6",  # Six
      55 => "7",  # Seven
      56 => "8",  # Eight
      57 => "9",  # Nine
      58 => ":",  # Colon
      59 => ";",  # Semicolon
      60 => "<",  # Less than
      61 => "=",  # Equals
      62 => ">",  # Greater than
      63 => "?",  # Question mark
      64 => "@",  # At sign
      65 => "A",  # A
      66 => "B",  # B
      67 => "C",  # C
      68 => "D",  # D
      69 => "E",  # E
      70 => "F",  # F
      71 => "G",  # G
      72 => "H",  # H
      73 => "I",  # I
      74 => "J",  # J
      75 => "K",  # K
      76 => "L",  # L
      77 => "M",  # M
      78 => "N",  # N
      79 => "O",  # O
      80 => "P",  # P
      81 => "Q",  # Q
      82 => "R",  # R
      83 => "S",  # S
      84 => "T",  # T
      85 => "U",  # U
      86 => "V",  # V
      87 => "W",  # W
      88 => "X",  # X
      89 => "Y",  # Y
      90 => "Z",  # Z
      91 => "[",  # Left square bracket
      92 => "\\", # Backslash
      93 => "]",  # Right square bracket
      94 => "^",  # Caret
      95 => "_",  # Underscore
      96 => "`",  # Backtick
      97 => "a",  # a
      98 => "b",  # b
      99 => "c",  # c
      100 => "d", # d
      101 => "e", # e
      102 => "f", # f
      103 => "g", # g
      104 => "h", # h
      105 => "i", # i
      106 => "j", # j
      107 => "k", # k
      108 => "l", # l
      109 => "m", # m
      110 => "n", # n
      111 => "o", # o
      112 => "p", # p
      113 => "q", # q
      114 => "r", # r
      115 => "s", # s
      116 => "t", # t
      117 => "u", # u
      118 => "v", # v
      119 => "w", # w
      120 => "x", # x
      121 => "y", # y
      122 => "z", # z
      123 => "{", # Left curly brace
      124 => "|", # Vertical bar
      125 => "}", # Right curly brace
      126 => "~"  # Tilde
    }
  end

  @doc """
  Returns the DEC Supplementary character map.
  """
  def dec_supplementary_map do
    %{
      # Box drawing characters
      ?l => "┌", # Upper left corner
      ?k => "┐", # Upper right corner
      ?j => "└", # Lower left corner
      ?m => "┘", # Lower right corner
      ?q => "─", # Horizontal line
      ?x => "│", # Vertical line
      ?t => "├", # Left T
      ?u => "┤", # Right T
      ?v => "┴", # Bottom T
      ?w => "┬", # Top T
      ?n => "┼", # Cross
      # Block elements
      ?a => "█", # Full block
      ?b => "▓", # Dark shade
      ?c => "▒", # Medium shade
      ?d => "░", # Light shade
      # Geometric shapes
      ?e => "◆", # Diamond
      ?f => "■", # Square
      ?g => "●", # Circle
      ?h => "○", # Circle
      ?i => "◎", # Circle
      ?j => "★", # Star
      ?k => "☆", # Star
      ?l => "◇", # Diamond
      ?m => "□", # Square
      ?n => "▣", # Square
      ?o => "▢", # Square
      ?p => "▤", # Square
      ?q => "▥", # Square
      ?r => "▦", # Square
      ?s => "▧", # Square
      ?t => "▨", # Square
      ?u => "▩", # Square
      ?v => "▪", # Square
      ?w => "▫", # Square
      ?x => "▬", # Square
      ?y => "▭", # Square
      ?z => "▮", # Square
      ?{ => "▯", # Square
      ?} => "▰", # Square
      ?| => "▱", # Square
      ?~ => "▲", # Square
      ?` => "△", # Square
      ?' => "▴", # Triangle
      ?" => "▵", # Triangle
      ?( => "▶", # Triangle
      ?) => "▷", # Triangle
      ?[ => "▸", # Triangle
      ?] => "▹", # Triangle
      ?< => "►", # Triangle
      ?> => "◄", # Triangle
      ?/ => "◅", # Triangle
      ?\\ => "▻" # Triangle
    }
  end

  @doc """
  Returns the DEC Special character map.
  """
  def dec_special_map do
    %{
      # Box drawing characters
      ?_ => "─", # Horizontal line
      ?| => "│", # Vertical line
      ?- => "┌", # Upper left corner
      ?+ => "┐", # Upper right corner
      ?* => "└", # Lower left corner
      ?# => "┘", # Lower right corner
      # Mathematical symbols
      ?~ => "≈", # Approximately equal
      ?^ => "↑", # Up arrow
      ?v => "↓", # Down arrow
      ?< => "←", # Left arrow
      ?> => "→", # Right arrow
      ?o => "°", # Degree symbol
      ?` => "±", # Plus-minus
      ?' => "′", # Prime
      ?" => "″", # Double prime
      ?! => "≠", # Not equal
      ?= => "≡", # Identical
      ?/ => "÷", # Division
      ?\\ => "×", # Multiplication
      ?[ => "≤", # Less than or equal
      ?] => "≥", # Greater than or equal
      ?{ => "⌈", # Ceiling
      ?} => "⌉", # Ceiling
      ?( => "⌊", # Floor
      ?) => "⌋", # Floor
      # Geometric shapes
      ?@ => "◆", # Diamond
      ?# => "■", # Square
      ?$ => "●", # Circle
      ?% => "○", # Circle
      ?& => "◎", # Circle
      ?* => "★", # Star
      ?+ => "⊕", # Plus
      ?- => "⊖", # Minus
      ?. => "·", # Middle dot
      ?/ => "/"  # Slash
    }
  end

  @doc """
  Returns the DEC Technical character map.
  """
  def dec_technical_map do
    %{
      # Greek letters
      ?a => "α", # Alpha
      ?b => "β", # Beta
      ?g => "γ", # Gamma
      ?d => "δ", # Delta
      ?e => "ε", # Epsilon
      ?z => "ζ", # Zeta
      ?h => "η", # Eta
      ?q => "θ", # Theta
      ?i => "ι", # Iota
      ?k => "κ", # Kappa
      ?l => "λ", # Lambda
      ?m => "μ", # Mu
      ?n => "ν", # Nu
      ?x => "ξ", # Xi
      ?o => "ο", # Omicron
      ?p => "π", # Pi
      ?r => "ρ", # Rho
      ?s => "σ", # Sigma
      ?t => "τ", # Tau
      ?u => "υ", # Upsilon
      ?f => "φ", # Phi
      ?c => "χ", # Chi
      ?y => "ψ", # Psi
      ?w => "ω", # Omega
      # Mathematical operators
      ?+ => "∑", # Summation
      ?- => "∏", # Product
      ?* => "∫", # Integral
      ?/ => "√", # Square root
      ?= => "≈", # Approximately equal
      ?< => "≤", # Less than or equal
      ?> => "≥", # Greater than or equal
      ?! => "≠", # Not equal
      ?@ => "∞", # Infinity
      ?# => "∇", # Nabla
      ?$ => "∂", # Partial derivative
      ?% => "∝", # Proportional to
      ?& => "∧", # Logical AND
      ?| => "∨", # Logical OR
      ?~ => "¬", # Logical NOT
      ?^ => "∩", # Intersection
      ?_ => "∪", # Union
      ?` => "∈", # Element of
      ?' => "∉", # Not element of
      ?" => "⊂", # Subset of
      ?( => "⊃", # Superset of
      ?) => "⊆", # Subset of or equal to
      ?[ => "⊇", # Superset of or equal to
      ?] => "⊄", # Not subset of
      ?{ => "⊅", # Not superset of
      ?} => "⊈", # Not subset of or equal to
      ?\\ => "⊉" # Not superset of or equal to
    }
  end

  @doc """
  Translates a character using the current charset.
  """
  def handle_set_charset(emulator, params_buffer, final_byte) do
    case {params_buffer, final_byte} do
      # US ASCII
      {[], ?B} ->
        {:ok,
         %{emulator | charset_state: %{emulator.charset_state | g0: :us_ascii}}}

      # DEC Special Graphics
      {[], ?0} ->
        {:ok,
         %{
           emulator
           | charset_state: %{emulator.charset_state | g0: :dec_special}
         }}

      # DEC Technical
      {[], ?>} ->
        {:ok,
         %{
           emulator
           | charset_state: %{emulator.charset_state | g0: :dec_technical}
         }}

      # DEC Supplemental
      {[], ?<} ->
        {:ok,
         %{
           emulator
           | charset_state: %{emulator.charset_state | g0: :dec_supplemental}
         }}

      # DEC Supplemental Graphics
      {[], "%5"} ->
        {:ok,
         %{
           emulator
           | charset_state: %{
               emulator.charset_state
               | g0: :dec_supplemental_graphics
             }
         }}

      # DEC Hebrew
      {[], "%6"} ->
        {:ok,
         %{
           emulator
           | charset_state: %{emulator.charset_state | g0: :dec_hebrew}
         }}

      # DEC Greek
      {[], "%7"} ->
        {:ok,
         %{emulator | charset_state: %{emulator.charset_state | g0: :dec_greek}}}

      # DEC Turkish
      {[], "%8"} ->
        {:ok,
         %{
           emulator
           | charset_state: %{emulator.charset_state | g0: :dec_turkish}
         }}

      # Unknown character set, ignore
      _ ->
        {:ok, emulator}
    end
  end

  @doc """
  Gets the current character set for the specified G-set.
  """
  def get_charset(emulator, g_set) do
    case g_set do
      :g0 -> emulator.charset_state.g0
      :g1 -> emulator.charset_state.g1
      :g2 -> emulator.charset_state.g2
      :g3 -> emulator.charset_state.g3
      _ -> :us_ascii
    end
  end

  @doc """
  Maps a character using the current character set.
  """
  def map_character(emulator, char) do
    charset = get_charset(emulator, emulator.charset_state.active_set)

    case charset do
      nil ->
        char

      charset_name ->
        char_map = emulator.charset_state.charsets[charset_name].()
        Map.get(char_map, char, char)
    end
  end

  # Character mapping functions for different character sets
  @doc false
  defp map_dec_special(char) do
    case char do
      # Horizontal line
      ?_ -> ?─
      # Vertical line
      ?| -> ?│
      # Upper left corner
      ?- -> ?┌
      # Upper right corner
      ?+ -> ?┐
      # Lower left corner
      ?* -> ?└
      # Lower right corner
      ?# -> ?┘
      # Approximately equal
      ?~ -> ?≈
      # Up arrow
      ?^ -> ?↑
      # Down arrow
      ?v -> ?↓
      # Left arrow
      ?< -> ?←
      # Right arrow
      ?> -> ?→
      # Degree symbol
      ?o -> ?°
      # Plus-minus
      ?` -> ?±
      # Prime
      ?' -> ?′
      # Double prime
      ?" -> ?″
      # Not equal
      ?! -> ?≠
      # Identical
      ?= -> ?≡
      # Division
      ?/ -> ?÷
      # Multiplication
      ?\\ -> ?×
      # Less than or equal
      ?[ -> ?≤
      # Greater than or equal
      ?] -> ?≥
      # Ceiling
      ?{ -> ?⌈
      # Ceiling
      ?} -> ?⌉
      # Floor
      ?( -> ?⌊
      # Floor
      ?) -> ?⌋
      # Diamond
      ?@ -> ?◆
      # Square
      ?# -> ?■
      # Circle
      ?$ -> ?●
      # Circle
      ?% -> ?○
      # Circle
      ?& -> ?◎
      # Star
      ?* -> ?★
      # Plus
      ?+ -> ?⊕
      # Minus
      ?- -> ?⊖
      # Middle dot
      ?. -> ?·
      # Slash
      ?/ -> ?/
      _ -> char
    end
  end

  @doc false
  defp map_dec_technical(char) do
    case char do
      # Mathematical symbols
      # Alpha
      ?a -> ?α
      # Beta
      ?b -> ?β
      # Gamma
      ?g -> ?γ
      # Delta
      ?d -> ?δ
      # Epsilon
      ?e -> ?ε
      # Zeta
      ?z -> ?ζ
      # Eta
      ?h -> ?η
      # Theta
      ?q -> ?θ
      # Iota
      ?i -> ?ι
      # Kappa
      ?k -> ?κ
      # Lambda
      ?l -> ?λ
      # Mu
      ?m -> ?μ
      # Nu
      ?n -> ?ν
      # Xi
      ?x -> ?ξ
      # Omicron
      ?o -> ?ο
      # Pi
      ?p -> ?π
      # Rho
      ?r -> ?ρ
      # Sigma
      ?s -> ?σ
      # Tau
      ?t -> ?τ
      # Upsilon
      ?u -> ?υ
      # Phi
      ?f -> ?φ
      # Chi
      ?c -> ?χ
      # Psi
      ?y -> ?ψ
      # Omega
      ?w -> ?ω
      # Mathematical operators
      # Summation
      ?+ -> ?∑
      # Product
      ?- -> ?∏
      # Integral
      ?* -> ?∫
      # Square root
      ?/ -> ?√
      # Approximately equal
      ?= -> ?≈
      # Less than or equal
      ?< -> ?≤
      # Greater than or equal
      ?> -> ?≥
      # Not equal
      ?! -> ?≠
      # Infinity
      ?@ -> ?∞
      # Nabla
      ?# -> ?∇
      # Partial derivative
      ?$ -> ?∂
      # Proportional to
      ?% -> ?∝
      # Logical AND
      ?& -> ?∧
      # Logical OR
      ?| -> ?∨
      # Logical NOT
      ?~ -> ?¬
      # Intersection
      ?^ -> ?∩
      # Union
      ?_ -> ?∪
      # Element of
      ?` -> ?∈
      # Not element of
      ?' -> ?∉
      # Subset of
      ?" -> ?⊂
      # Superset of
      ?( -> ?⊃
      # Subset of or equal to
      ?) -> ?⊆
      # Superset of or equal to
      ?[ -> ?⊇
      # Not subset of
      ?] -> ?⊄
      # Not superset of
      ?{ -> ?⊅
      # Not subset of or equal to
      ?} -> ?⊈
      # Not superset of or equal to
      ?\\ -> ?⊉
      _ -> char
    end
  end

  @doc false
  defp map_math_operators(char) do
    case char do
      # Mathematical operators
      # Summation
      ?+ -> ?∑
      # Product
      ?- -> ?∏
      # Integral
      ?* -> ?∫
      # Square root
      ?/ -> ?√
      # Approximately equal
      ?= -> ?≈
      # Less than or equal
      ?< -> ?≤
      # Greater than or equal
      ?> -> ?≥
      # Not equal
      ?! -> ?≠
      # Infinity
      ?@ -> ?∞
      # Nabla
      ?# -> ?∇
      # Partial derivative
      ?$ -> ?∂
      # Proportional to
      ?% -> ?∝
      # Logical AND
      ?& -> ?∧
      # Logical OR
      ?| -> ?∨
      # Logical NOT
      ?~ -> ?¬
      # Intersection
      ?^ -> ?∩
      # Union
      ?_ -> ?∪
      # Element of
      ?` -> ?∈
      # Not element of
      ?' -> ?∉
      # Subset of
      ?" -> ?⊂
      # Superset of
      ?( -> ?⊃
      # Subset of or equal to
      ?) -> ?⊆
      # Superset of or equal to
      ?[ -> ?⊇
      # Not subset of
      ?] -> ?⊄
      # Not superset of
      ?{ -> ?⊅
      # Not subset of or equal to
      ?} -> ?⊈
      # Not superset of or equal to
      ?\\ -> ?⊉
      _ -> char
    end
  end

  @doc false
  defp map_dec_supplemental(char) do
    case char do
      # Box drawing characters
      # Upper left corner
      ?l -> ?┌
      # Upper right corner
      ?k -> ?┐
      # Lower left corner
      ?j -> ?└
      # Lower right corner
      ?m -> ?┘
      # Horizontal line
      ?q -> ?─
      # Vertical line
      ?x -> ?│
      # Left T
      ?t -> ?├
      # Right T
      ?u -> ?┤
      # Bottom T
      ?v -> ?┴
      # Top T
      ?w -> ?┬
      # Cross
      ?n -> ?┼
      # Block elements
      # Full block
      ?a -> ?█
      # Dark shade
      ?b -> ?▓
      # Medium shade
      ?c -> ?▒
      # Light shade
      ?d -> ?░
      # Geometric shapes
      # Diamond
      ?e -> ?◆
      # Square
      ?f -> ?■
      # Circle
      ?g -> ?●
      # Circle
      ?h -> ?○
      # Circle
      ?i -> ?◎
      # Star
      ?j -> ?★
      # Star
      ?k -> ?☆
      # Diamond
      ?l -> ?◇
      # Square
      ?m -> ?□
      # Square
      ?n -> ?▣
      # Square
      ?o -> ?▢
      # Square
      ?p -> ?▤
      # Square
      ?q -> ?▥
      # Square
      ?r -> ?▦
      # Square
      ?s -> ?▧
      # Square
      ?t -> ?▨
      # Square
      ?u -> ?▩
      # Square
      ?v -> ?▪
      # Square
      ?w -> ?▫
      # Square
      ?x -> ?▬
      # Square
      ?y -> ?▭
      # Square
      ?z -> ?▮
      # Square
      ?{ -> ?▯
      # Square
      ?} -> ?▰
      # Square
      ?| -> ?▱
      # Square
      ?~ -> ?▲
      # Square
      ?` -> ?△
      # Triangle
      ?' -> ?▴
      # Triangle
      ?" -> ?▵
      # Triangle
      ?( -> ?▶
      # Triangle
      ?) -> ?▷
      # Triangle
      ?[ -> ?▸
      # Triangle
      ?] -> ?▹
      # Triangle
      ?< -> ?►
      # Triangle
      ?> -> ?◄
      # Triangle
      ?/ -> ?◅
      # Triangle
      ?\\ -> ?▻
      _ -> map_math_operators(char)
    end
  end

  @doc false
  defp map_dec_supplemental_graphics(char) do
    case char do
      # Arrows
      # Up arrow
      ?^ -> ?↑
      # Down arrow
      ?v -> ?↓
      # Left arrow
      ?< -> ?←
      # Right arrow
      ?> -> ?→
      # Northwest arrow
      ?A -> ?↖
      # Northeast arrow
      ?B -> ?↗
      # Southeast arrow
      ?C -> ?↘
      # Southwest arrow
      ?D -> ?↙
      # Left right arrow
      ?E -> ?↔
      # Up down arrow
      ?F -> ?↕
      # Up down arrow with base
      ?G -> ?↨
      # Up down arrow
      ?H -> ?↕
      # Left right arrow
      ?I -> ?↔
      # Left right arrow
      ?J -> ?↔
      # Up down arrow
      ?K -> ?↕
      # Up down arrow
      ?L -> ?↕
      _ -> map_math_operators(char)
    end
  end

  @doc false
  defp map_dec_hebrew(char) do
    case char do
      # Alef
      ?a -> ?א
      # Bet
      ?b -> ?ב
      # Gimel
      ?g -> ?ג
      # Dalet
      ?d -> ?ד
      # He
      ?h -> ?ה
      # Vav
      ?v -> ?ו
      # Zayin
      ?z -> ?ז
      # Het
      ?H -> ?ח
      # Tet
      ?T -> ?ט
      # Yod
      ?y -> ?י
      # Kaf
      ?k -> ?כ
      # Lamed
      ?l -> ?ל
      # Mem
      ?m -> ?מ
      # Nun
      ?n -> ?נ
      # Samekh
      ?s -> ?ס
      # Ayin
      ?( -> ?ע
      # Pe
      ?p -> ?פ
      # Tsadi
      ?c -> ?צ
      # Qof
      ?q -> ?ק
      # Resh
      ?r -> ?ר
      # Shin
      ?S -> ?ש
      # Tav
      ?t -> ?ת
      # Final Kaf
      ?K -> ?ך
      # Final Mem
      ?M -> ?ם
      # Final Nun
      ?N -> ?ן
      # Final Pe
      ?P -> ?ף
      # Final Tsadi
      ?Z -> ?ץ
      _ -> char
    end
  end

  @doc false
  defp map_dec_greek(char) do
    case char do
      # Uppercase Greek letters
      # Alpha
      ?A -> ?Α
      # Beta
      ?B -> ?Β
      # Gamma
      ?G -> ?Γ
      # Delta
      ?D -> ?Δ
      # Epsilon
      ?E -> ?Ε
      # Zeta
      ?Z -> ?Ζ
      # Eta
      ?H -> ?Η
      # Theta
      ?Q -> ?Θ
      # Iota
      ?I -> ?Ι
      # Kappa
      ?K -> ?Κ
      # Lambda
      ?L -> ?Λ
      # Mu
      ?M -> ?Μ
      # Nu
      ?N -> ?Ν
      # Xi
      ?X -> ?Ξ
      # Omicron
      ?O -> ?Ο
      # Pi
      ?P -> ?Π
      # Rho
      ?R -> ?Ρ
      # Sigma
      ?S -> ?Σ
      # Tau
      ?T -> ?Τ
      # Upsilon
      ?U -> ?Υ
      # Phi
      ?F -> ?Φ
      # Chi
      ?C -> ?Χ
      # Psi
      ?Y -> ?Ψ
      # Omega
      ?W -> ?Ω
      # Lowercase Greek letters
      # Alpha
      ?a -> ?α
      # Beta
      ?b -> ?β
      # Gamma
      ?g -> ?γ
      # Delta
      ?d -> ?δ
      # Epsilon
      ?e -> ?ε
      # Zeta
      ?z -> ?ζ
      # Eta
      ?h -> ?η
      # Theta
      ?q -> ?θ
      # Iota
      ?i -> ?ι
      # Kappa
      ?k -> ?κ
      # Lambda
      ?l -> ?λ
      # Mu
      ?m -> ?μ
      # Nu
      ?n -> ?ν
      # Xi
      ?x -> ?ξ
      # Omicron
      ?o -> ?ο
      # Pi
      ?p -> ?π
      # Rho
      ?r -> ?ρ
      # Sigma
      ?s -> ?σ
      # Tau
      ?t -> ?τ
      # Upsilon
      ?u -> ?υ
      # Phi
      ?f -> ?φ
      # Chi
      ?c -> ?χ
      # Psi
      ?y -> ?ψ
      # Omega
      ?w -> ?ω
      # Special characters
      # Middle dot
      ?; -> ?·
      # Acute accent
      ?' -> ?'
      # Grave accent
      ?` -> ?`
      # Circumflex
      ?^ -> ?^
      # Tilde
      ?~ -> ?~
      # Diaeresis
      ?" -> ?"
      _ -> char
    end
  end

  @doc false
  defp map_dec_turkish(char) do
    case char do
      # Uppercase Turkish letters
      # A
      ?A -> ?A
      # B
      ?B -> ?B
      # C
      ?C -> ?C
      # D
      ?D -> ?D
      # E
      ?E -> ?E
      # F
      ?F -> ?F
      # G
      ?G -> ?G
      # H
      ?H -> ?H
      # I
      ?I -> ?I
      # J
      ?J -> ?J
      # K
      ?K -> ?K
      # L
      ?L -> ?L
      # M
      ?M -> ?M
      # N
      ?N -> ?N
      # O
      ?O -> ?O
      # P
      ?P -> ?P
      # R
      ?R -> ?R
      # S
      ?S -> ?S
      # T
      ?T -> ?T
      # U
      ?U -> ?U
      # V
      ?V -> ?V
      # Y
      ?Y -> ?Y
      # Z
      ?Z -> ?Z
      # Lowercase Turkish letters
      # a
      ?a -> ?a
      # b
      ?b -> ?b
      # c
      ?c -> ?c
      # d
      ?d -> ?d
      # e
      ?e -> ?e
      # f
      ?f -> ?f
      # g
      ?g -> ?g
      # h
      ?h -> ?h
      # i
      ?i -> ?i
      # j
      ?j -> ?j
      # k
      ?k -> ?k
      # l
      ?l -> ?l
      # m
      ?m -> ?m
      # n
      ?n -> ?n
      # o
      ?o -> ?o
      # p
      ?p -> ?p
      # r
      ?r -> ?r
      # s
      ?s -> ?s
      # t
      ?t -> ?t
      # u
      ?u -> ?u
      # v
      ?v -> ?v
      # y
      ?y -> ?y
      # z
      ?z -> ?z
      # Special Turkish characters
      # G with breve
      ?{ -> ?Ğ
      # g with breve
      ?} -> ?ğ
      # I with dot
      ?[ -> ?İ
      # i without dot
      ?] -> ?ı
      # S with cedilla
      ?\\ -> ?Ş
      # s with cedilla
      ?| -> ?ş
      # O with diaeresis
      ?' -> ?Ö
      # o with diaeresis
      ?" -> ?ö
      # U with diaeresis
      ?< -> ?Ü
      # u with diaeresis
      ?> -> ?ü
      # C with cedilla
      ?` -> ?Ç
      # c with cedilla
      ?~ -> ?ç
      _ -> char
    end
  end
end
