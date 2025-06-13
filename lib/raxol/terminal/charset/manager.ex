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
  @spec update_state(EmulatorStruct.t(), CharacterSets.charset_state()) :: EmulatorStruct.t()
  def update_state(emulator, state) do
    %{emulator | charset_state: state}
  end

  @doc """
  Designates a character set for the specified G-set.
  """
  @spec designate_charset(EmulatorStruct.t(), atom(), atom()) :: EmulatorStruct.t()
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
      emulator.charset_state |
      g_sets: %{},
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
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :us_ascii}}}

      # DEC Special Graphics
      {[], ?0} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_special}}}

      # DEC Technical
      {[], ?>} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_technical}}}

      # DEC Supplemental
      {[], ?<} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_supplemental}}}

      # DEC Supplemental Graphics
      {[], "%5"} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_supplemental_graphics}}}

      # DEC Hebrew
      {[], "%6"} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_hebrew}}}

      # DEC Greek
      {[], "%7"} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_greek}}}

      # DEC Turkish
      {[], "%8"} ->
        {:ok, %{emulator | charset_state: %{emulator.charset_state | g0: :dec_turkish}}}

      # Unknown character set, ignore
      _ -> {:ok, emulator}
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
      ?_ -> ?─  # Horizontal line
      ?| -> ?│  # Vertical line
      ?- -> ?┌  # Upper left corner
      ?+ -> ?┐  # Upper right corner
      ?* -> ?└  # Lower left corner
      ?# -> ?┘  # Lower right corner
      ?~ -> ?≈  # Approximately equal
      ?^ -> ?↑  # Up arrow
      ?v -> ?↓  # Down arrow
      ?< -> ?←  # Left arrow
      ?> -> ?→  # Right arrow
      ?o -> ?°  # Degree symbol
      ?` -> ?±  # Plus-minus
      ?' -> ?′  # Prime
      ?" -> ?″  # Double prime
      ?! -> ?≠  # Not equal
      ?= -> ?≡  # Identical
      ?/ -> ?÷  # Division
      ?\\ -> ?×  # Multiplication
      ?[ -> ?≤  # Less than or equal
      ?] -> ?≥  # Greater than or equal
      ?{ -> ?⌈  # Ceiling
      ?} -> ?⌉  # Ceiling
      ?( -> ?⌊  # Floor
      ?) -> ?⌋  # Floor
      ?@ -> ?◆  # Diamond
      ?# -> ?■  # Square
      ?$ -> ?●  # Circle
      ?% -> ?○  # Circle
      ?& -> ?◎  # Circle
      ?* -> ?★  # Star
      ?+ -> ?⊕  # Plus
      ?- -> ?⊖  # Minus
      ?. -> ?·  # Middle dot
      ?/ -> ?/  # Slash
      _ -> char
    end
  end

  defp map_dec_technical(char) do
    case char do
      # Mathematical symbols
      ?a -> ?α  # Alpha
      ?b -> ?β  # Beta
      ?g -> ?γ  # Gamma
      ?d -> ?δ  # Delta
      ?e -> ?ε  # Epsilon
      ?z -> ?ζ  # Zeta
      ?h -> ?η  # Eta
      ?q -> ?θ  # Theta
      ?i -> ?ι  # Iota
      ?k -> ?κ  # Kappa
      ?l -> ?λ  # Lambda
      ?m -> ?μ  # Mu
      ?n -> ?ν  # Nu
      ?x -> ?ξ  # Xi
      ?o -> ?ο  # Omicron
      ?p -> ?π  # Pi
      ?r -> ?ρ  # Rho
      ?s -> ?σ  # Sigma
      ?t -> ?τ  # Tau
      ?u -> ?υ  # Upsilon
      ?f -> ?φ  # Phi
      ?c -> ?χ  # Chi
      ?y -> ?ψ  # Psi
      ?w -> ?ω  # Omega

      # Mathematical operators
      ?+ -> ?∑  # Summation
      ?- -> ?∏  # Product
      ?* -> ?∫  # Integral
      ?/ -> ?√  # Square root
      ?= -> ?≈  # Approximately equal
      ?< -> ?≤  # Less than or equal
      ?> -> ?≥  # Greater than or equal
      ?! -> ?≠  # Not equal
      ?@ -> ?∞  # Infinity
      ?# -> ?∇  # Nabla
      ?$ -> ?∂  # Partial derivative
      ?% -> ?∝  # Proportional to
      ?& -> ?∧  # Logical AND
      ?| -> ?∨  # Logical OR
      ?~ -> ?¬  # Logical NOT
      ?^ -> ?∩  # Intersection
      ?_ -> ?∪  # Union
      ?` -> ?∈  # Element of
      ?' -> ?∉  # Not element of
      ?" -> ?⊂  # Subset of
      ?( -> ?⊃  # Superset of
      ?) -> ?⊆  # Subset of or equal to
      ?[ -> ?⊇  # Superset of or equal to
      ?] -> ?⊄  # Not subset of
      ?{ -> ?⊅  # Not superset of
      ?} -> ?⊈  # Not subset of or equal to
      ?\\ -> ?⊉  # Not superset of or equal to
      _ -> char
    end
  end

  defp map_math_operators(char) do
    case char do
      # Mathematical operators
      ?+ -> ?∑  # Summation
      ?- -> ?∏  # Product
      ?* -> ?∫  # Integral
      ?/ -> ?√  # Square root
      ?= -> ?≈  # Approximately equal
      ?< -> ?≤  # Less than or equal
      ?> -> ?≥  # Greater than or equal
      ?! -> ?≠  # Not equal
      ?@ -> ?∞  # Infinity
      ?# -> ?∇  # Nabla
      ?$ -> ?∂  # Partial derivative
      ?% -> ?∝  # Proportional to
      ?& -> ?∧  # Logical AND
      ?| -> ?∨  # Logical OR
      ?~ -> ?¬  # Logical NOT
      ?^ -> ?∩  # Intersection
      ?_ -> ?∪  # Union
      ?` -> ?∈  # Element of
      ?' -> ?∉  # Not element of
      ?" -> ?⊂  # Subset of
      ?( -> ?⊃  # Superset of
      ?) -> ?⊆  # Subset of or equal to
      ?[ -> ?⊇  # Superset of or equal to
      ?] -> ?⊄  # Not subset of
      ?{ -> ?⊅  # Not superset of
      ?} -> ?⊈  # Not subset of or equal to
      ?\\ -> ?⊉  # Not superset of or equal to
      _ -> char
    end
  end

  defp map_dec_supplemental(char) do
    case char do
      # Box drawing characters
      ?l -> ?┌  # Upper left corner
      ?k -> ?┐  # Upper right corner
      ?j -> ?└  # Lower left corner
      ?m -> ?┘  # Lower right corner
      ?q -> ?─  # Horizontal line
      ?x -> ?│  # Vertical line
      ?t -> ?├  # Left T
      ?u -> ?┤  # Right T
      ?v -> ?┴  # Bottom T
      ?w -> ?┬  # Top T
      ?n -> ?┼  # Cross

      # Block elements
      ?a -> ?█  # Full block
      ?b -> ?▓  # Dark shade
      ?c -> ?▒  # Medium shade
      ?d -> ?░  # Light shade

      # Geometric shapes
      ?e -> ?◆  # Diamond
      ?f -> ?■  # Square
      ?g -> ?●  # Circle
      ?h -> ?○  # Circle
      ?i -> ?◎  # Circle
      ?j -> ?★  # Star
      ?k -> ?☆  # Star
      ?l -> ?◇  # Diamond
      ?m -> ?□  # Square
      ?n -> ?▣  # Square
      ?o -> ?▢  # Square
      ?p -> ?▤  # Square
      ?q -> ?▥  # Square
      ?r -> ?▦  # Square
      ?s -> ?▧  # Square
      ?t -> ?▨  # Square
      ?u -> ?▩  # Square
      ?v -> ?▪  # Square
      ?w -> ?▫  # Square
      ?x -> ?▬  # Square
      ?y -> ?▭  # Square
      ?z -> ?▮  # Square
      ?{ -> ?▯  # Square
      ?} -> ?▰  # Square
      ?| -> ?▱  # Square
      ?~ -> ?▲  # Square
      ?` -> ?△  # Square
      ?' -> ?▴  # Triangle
      ?" -> ?▵  # Triangle
      ?( -> ?▶  # Triangle
      ?) -> ?▷  # Triangle
      ?[ -> ?▸  # Triangle
      ?] -> ?▹  # Triangle
      ?< -> ?►  # Triangle
      ?> -> ?◄  # Triangle
      ?/ -> ?◅  # Triangle
      ?\\ -> ?▻  # Triangle
      _ -> map_math_operators(char)
    end
  end

  defp map_dec_supplemental_graphics(char) do
    case char do
      # Arrows
      ?^ -> ?↑  # Up arrow
      ?v -> ?↓  # Down arrow
      ?< -> ?←  # Left arrow
      ?> -> ?→  # Right arrow
      ?A -> ?↖  # Northwest arrow
      ?B -> ?↗  # Northeast arrow
      ?C -> ?↘  # Southeast arrow
      ?D -> ?↙  # Southwest arrow
      ?E -> ?↔  # Left right arrow
      ?F -> ?↕  # Up down arrow
      ?G -> ?↨  # Up down arrow with base
      ?H -> ?↕  # Up down arrow
      ?I -> ?↔  # Left right arrow
      ?J -> ?↔  # Left right arrow
      ?K -> ?↕  # Up down arrow
      ?L -> ?↕  # Up down arrow
      _ -> map_math_operators(char)
    end
  end

  defp map_dec_hebrew(char) do
    case char do
      ?a -> ?א  # Alef
      ?b -> ?ב  # Bet
      ?g -> ?ג  # Gimel
      ?d -> ?ד  # Dalet
      ?h -> ?ה  # He
      ?v -> ?ו  # Vav
      ?z -> ?ז  # Zayin
      ?H -> ?ח  # Het
      ?T -> ?ט  # Tet
      ?y -> ?י  # Yod
      ?k -> ?כ  # Kaf
      ?l -> ?ל  # Lamed
      ?m -> ?מ  # Mem
      ?n -> ?נ  # Nun
      ?s -> ?ס  # Samekh
      ?( -> ?ע  # Ayin
      ?p -> ?פ  # Pe
      ?c -> ?צ  # Tsadi
      ?q -> ?ק  # Qof
      ?r -> ?ר  # Resh
      ?S -> ?ש  # Shin
      ?t -> ?ת  # Tav
      ?K -> ?ך  # Final Kaf
      ?M -> ?ם  # Final Mem
      ?N -> ?ן  # Final Nun
      ?P -> ?ף  # Final Pe
      ?Z -> ?ץ  # Final Tsadi
      _ -> char
    end
  end

  defp map_dec_greek(char) do
    case char do
      # Uppercase Greek letters
      ?A -> ?Α  # Alpha
      ?B -> ?Β  # Beta
      ?G -> ?Γ  # Gamma
      ?D -> ?Δ  # Delta
      ?E -> ?Ε  # Epsilon
      ?Z -> ?Ζ  # Zeta
      ?H -> ?Η  # Eta
      ?Q -> ?Θ  # Theta
      ?I -> ?Ι  # Iota
      ?K -> ?Κ  # Kappa
      ?L -> ?Λ  # Lambda
      ?M -> ?Μ  # Mu
      ?N -> ?Ν  # Nu
      ?X -> ?Ξ  # Xi
      ?O -> ?Ο  # Omicron
      ?P -> ?Π  # Pi
      ?R -> ?Ρ  # Rho
      ?S -> ?Σ  # Sigma
      ?T -> ?Τ  # Tau
      ?U -> ?Υ  # Upsilon
      ?F -> ?Φ  # Phi
      ?C -> ?Χ  # Chi
      ?Y -> ?Ψ  # Psi
      ?W -> ?Ω  # Omega

      # Lowercase Greek letters
      ?a -> ?α  # Alpha
      ?b -> ?β  # Beta
      ?g -> ?γ  # Gamma
      ?d -> ?δ  # Delta
      ?e -> ?ε  # Epsilon
      ?z -> ?ζ  # Zeta
      ?h -> ?η  # Eta
      ?q -> ?θ  # Theta
      ?i -> ?ι  # Iota
      ?k -> ?κ  # Kappa
      ?l -> ?λ  # Lambda
      ?m -> ?μ  # Mu
      ?n -> ?ν  # Nu
      ?x -> ?ξ  # Xi
      ?o -> ?ο  # Omicron
      ?p -> ?π  # Pi
      ?r -> ?ρ  # Rho
      ?s -> ?σ  # Sigma
      ?t -> ?τ  # Tau
      ?u -> ?υ  # Upsilon
      ?f -> ?φ  # Phi
      ?c -> ?χ  # Chi
      ?y -> ?ψ  # Psi
      ?w -> ?ω  # Omega

      # Special characters
      ?; -> ?·  # Middle dot
      ?' -> ?'  # Acute accent
      ?` -> ?`  # Grave accent
      ?^ -> ?^  # Circumflex
      ?~ -> ?~  # Tilde
      ?" -> ?"  # Diaeresis
      _ -> char
    end
  end

  defp map_dec_turkish(char) do
    case char do
      # Uppercase Turkish letters
      ?A -> ?A  # A
      ?B -> ?B  # B
      ?C -> ?C  # C
      ?D -> ?D  # D
      ?E -> ?E  # E
      ?F -> ?F  # F
      ?G -> ?G  # G
      ?H -> ?H  # H
      ?I -> ?I  # I
      ?J -> ?J  # J
      ?K -> ?K  # K
      ?L -> ?L  # L
      ?M -> ?M  # M
      ?N -> ?N  # N
      ?O -> ?O  # O
      ?P -> ?P  # P
      ?R -> ?R  # R
      ?S -> ?S  # S
      ?T -> ?T  # T
      ?U -> ?U  # U
      ?V -> ?V  # V
      ?Y -> ?Y  # Y
      ?Z -> ?Z  # Z

      # Lowercase Turkish letters
      ?a -> ?a  # a
      ?b -> ?b  # b
      ?c -> ?c  # c
      ?d -> ?d  # d
      ?e -> ?e  # e
      ?f -> ?f  # f
      ?g -> ?g  # g
      ?h -> ?h  # h
      ?i -> ?i  # i
      ?j -> ?j  # j
      ?k -> ?k  # k
      ?l -> ?l  # l
      ?m -> ?m  # m
      ?n -> ?n  # n
      ?o -> ?o  # o
      ?p -> ?p  # p
      ?r -> ?r  # r
      ?s -> ?s  # s
      ?t -> ?t  # t
      ?u -> ?u  # u
      ?v -> ?v  # v
      ?y -> ?y  # y
      ?z -> ?z  # z

      # Special Turkish characters
      ?{ -> ?Ğ  # G with breve
      ?} -> ?ğ  # g with breve
      ?[ -> ?İ  # I with dot
      ?] -> ?ı  # i without dot
      ?\\ -> ?Ş  # S with cedilla
      ?| -> ?ş  # s with cedilla
      ?' -> ?Ö  # O with diaeresis
      ?" -> ?ö  # o with diaeresis
      ?< -> ?Ü  # U with diaeresis
      ?> -> ?ü  # u with diaeresis
      ?` -> ?Ç  # C with cedilla
      ?~ -> ?ç  # c with cedilla
      _ -> char
    end
  end
end
