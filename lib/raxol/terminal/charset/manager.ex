defmodule Raxol.Terminal.Charset.Manager do
  @moduledoc """
  Manages character set operations for the terminal emulator.
  This module handles character set designation, invocation, and state management.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.CharacterSets

  @type t :: %__MODULE__{
          state: CharacterSets.charset_state(),
          g_sets: map(),
          single_shift: atom() | nil
        }

  defstruct [:state, :g_sets, :single_shift]

  @doc """
  Creates a new character set state.
  """
  @spec new() :: CharacterSets.charset_state()
  def new do
    CharacterSets.new()
  end

  @doc """
  Gets the current character set state.
  """
  @spec get_state(EmulatorStruct.t()) :: CharacterSets.charset_state()
  def get_state(emulator) do
    emulator.charset_state
  end

  @doc """
  Updates the character set state.
  """
  @spec update_state(EmulatorStruct.t(), CharacterSets.charset_state()) ::
          EmulatorStruct.t()
  def update_state(emulator, state) do
    %{emulator | charset_state: state}
  end

  @doc """
  Designates a character set for the specified G-set.
  """
  @spec designate_charset(EmulatorStruct.t(), atom(), atom()) ::
          EmulatorStruct.t()
  def designate_charset(emulator, g_set, charset) do
    g_sets = Map.put(emulator.charset_state.g_sets, g_set, charset)
    state = %{emulator.charset_state | g_sets: g_sets}
    %{emulator | charset_state: state}
  end

  @doc """
  Invokes a G-set.
  """
  @spec invoke_g_set(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def invoke_g_set(emulator, g_set) do
    state = %{emulator.charset_state | current_g_set: g_set}
    %{emulator | charset_state: state}
  end

  @doc """
  Gets the current G-set.
  """
  @spec get_current_g_set(EmulatorStruct.t()) :: atom()
  def get_current_g_set(emulator) do
    emulator.charset_state.current_g_set
  end

  @doc """
  Gets the designated character set for a G-set.
  """
  @spec get_designated_charset(EmulatorStruct.t(), atom()) :: atom()
  def get_designated_charset(emulator, g_set) do
    emulator.charset_state.g_sets[g_set]
  end

  @doc """
  Resets character set state to defaults.
  """
  @spec reset_state(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_state(emulator) do
    state = %{
      emulator.charset_state
      | g_sets: %{},
        current_g_set: :g0,
        single_shift: nil
    }

    %{emulator | charset_state: state}
  end

  @doc """
  Applies single shift to a G-set.
  """
  @spec apply_single_shift(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def apply_single_shift(emulator, g_set) do
    state = %{emulator.charset_state | single_shift: g_set}
    %{emulator | charset_state: state}
  end

  @doc """
  Gets the current single shift state.
  """
  @spec get_single_shift(EmulatorStruct.t()) :: atom() | nil
  def get_single_shift(emulator) do
    emulator.charset_state.single_shift
  end

  @doc """
  Handles Set Character Set (SCS) commands.
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
      :us_ascii -> char
      :dec_special -> map_dec_special(char)
      :dec_technical -> map_dec_technical(char)
      :dec_supplemental -> map_dec_supplemental(char)
      :dec_supplemental_graphics -> map_dec_supplemental_graphics(char)
      :dec_hebrew -> map_dec_hebrew(char)
      :dec_greek -> map_dec_greek(char)
      :dec_turkish -> map_dec_turkish(char)
      _ -> char
    end
  end

  # Character mapping functions for different character sets
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
