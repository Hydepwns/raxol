defmodule Raxol.Terminal.Charset.Maps do
  @moduledoc """
  Provides character mapping functions for different character sets.
  """

  @doc """
  Returns the US ASCII character map.
  """
  def us_ascii_map do
    %{
      # Space
      32 => " ",
      # Exclamation mark
      33 => "!",
      # Double quote
      34 => "\"",
      # Hash
      35 => "#",
      # Dollar sign
      36 => "$",
      # Percent
      37 => "%",
      # Ampersand
      38 => "&",
      # Single quote
      39 => "'",
      # Left parenthesis
      40 => "(",
      # Right parenthesis
      41 => ")",
      # Asterisk
      42 => "*",
      # Plus
      43 => "+",
      # Comma
      44 => ",",
      # Hyphen
      45 => "-",
      # Period
      46 => ".",
      # Forward slash
      47 => "/",
      # Zero
      48 => "0",
      # One
      49 => "1",
      # Two
      50 => "2",
      # Three
      51 => "3",
      # Four
      52 => "4",
      # Five
      53 => "5",
      # Six
      54 => "6",
      # Seven
      55 => "7",
      # Eight
      56 => "8",
      # Nine
      57 => "9",
      # Colon
      58 => ":",
      # Semicolon
      59 => ";",
      # Less than
      60 => "<",
      # Equals
      61 => "=",
      # Greater than
      62 => ">",
      # Question mark
      63 => "?",
      # At sign
      64 => "@",
      # A
      65 => "A",
      # B
      66 => "B",
      # C
      67 => "C",
      # D
      68 => "D",
      # E
      69 => "E",
      # F
      70 => "F",
      # G
      71 => "G",
      # H
      72 => "H",
      # I
      73 => "I",
      # J
      74 => "J",
      # K
      75 => "K",
      # L
      76 => "L",
      # M
      77 => "M",
      # N
      78 => "N",
      # O
      79 => "O",
      # P
      80 => "P",
      # Q
      81 => "Q",
      # R
      82 => "R",
      # S
      83 => "S",
      # T
      84 => "T",
      # U
      85 => "U",
      # V
      86 => "V",
      # W
      87 => "W",
      # X
      88 => "X",
      # Y
      89 => "Y",
      # Z
      90 => "Z",
      # Left square bracket
      91 => "[",
      # Backslash
      92 => "\\",
      # Right square bracket
      93 => "]",
      # Caret
      94 => "^",
      # Underscore
      95 => "_",
      # Backtick
      96 => "`",
      # a
      97 => "a",
      # b
      98 => "b",
      # c
      99 => "c",
      # d
      100 => "d",
      # e
      101 => "e",
      # f
      102 => "f",
      # g
      103 => "g",
      # h
      104 => "h",
      # i
      105 => "i",
      # j
      106 => "j",
      # k
      107 => "k",
      # l
      108 => "l",
      # m
      109 => "m",
      # n
      110 => "n",
      # o
      111 => "o",
      # p
      112 => "p",
      # q
      113 => "q",
      # r
      114 => "r",
      # s
      115 => "s",
      # t
      116 => "t",
      # u
      117 => "u",
      # v
      118 => "v",
      # w
      119 => "w",
      # x
      120 => "x",
      # y
      121 => "y",
      # z
      122 => "z",
      # Left curly brace
      123 => "{",
      # Vertical bar
      124 => "|",
      # Right curly brace
      125 => "}",
      # Tilde
      126 => "~"
    }
  end

  @doc """
  Returns the DEC Supplementary character map.
  """
  def dec_supplementary_map do
    %{
      # Box drawing characters
      # Upper left corner
      ?l => "┌",
      # Upper right corner
      ?k => "┐",
      # Lower left corner
      ?j => "└",
      # Lower right corner
      ?m => "┘",
      # Horizontal line
      ?q => "─",
      # Vertical line
      ?x => "│",
      # Left T
      ?t => "├",
      # Right T
      ?u => "┤",
      # Bottom T
      ?v => "┴",
      # Top T
      ?w => "┬",
      # Cross
      ?n => "┼",
      # Block elements
      # Full block
      ?a => "█",
      # Dark shade
      ?b => "▓",
      # Medium shade
      ?c => "▒",
      # Light shade
      ?d => "░",
      # Geometric shapes
      # Diamond
      ?e => "◆",
      # Square
      ?f => "■",
      # Circle
      ?g => "●",
      # Circle
      ?h => "○",
      # Circle
      ?i => "◎",
      # Star
      ?j => "★",
      # Star
      ?k => "☆",
      # Diamond
      ?l => "◇",
      # Square
      ?m => "□",
      # Square
      ?n => "▣",
      # Square
      ?o => "▢",
      # Square
      ?p => "▤",
      # Square
      ?q => "▥",
      # Square
      ?r => "▦",
      # Square
      ?s => "▧",
      # Square
      ?t => "▨",
      # Square
      ?u => "▩",
      # Square
      ?v => "▪",
      # Square
      ?w => "▫",
      # Square
      ?x => "▬",
      # Square
      ?y => "▭",
      # Square
      ?z => "▮",
      # Square
      ?{ => "▯",
      # Square
      ?} => "▰",
      # Square
      ?| => "▱",
      # Square
      ?~ => "▲",
      # Square
      ?` => "△",
      # Triangle
      ?' => "▴",
      # Triangle
      ?( => "▶",
      # Triangle
      ?) => "▷",
      # Triangle
      ?[ => "▸",
      # Triangle
      ?] => "▹",
      # Triangle
      ?< => "►",
      # Triangle
      ?> => "◄",
      # Triangle
      ?/ => "◅",
      # Triangle
      ?\\ => "▻"
    }
  end

  @doc """
  Returns the DEC Special character map.
  """
  def dec_special_map do
    %{
      # Box drawing characters
      # Horizontal line
      ?_ => "─",
      # Vertical line
      ?| => "│",
      # Upper left corner
      ?- => "┌",
      # Upper right corner
      ?+ => "┐",
      # Lower left corner
      ?* => "└",
      # Lower right corner
      ?# => "┘",
      # Mathematical symbols
      # Approximately equal
      ?~ => "≈",
      # Up arrow
      ?^ => "↑",
      # Down arrow
      ?v => "↓",
      # Left arrow
      ?< => "←",
      # Right arrow
      ?> => "→",
      # Degree symbol
      ?o => "°",
      # Plus-minus
      ?` => "±",
      # Prime
      ?' => "′",
      # Not equal
      ?! => "≠",
      # Identical
      ?= => "≡",
      # Division
      ?/ => "÷",
      # Multiplication
      ?\\ => "×",
      # Less than or equal
      ?[ => "≤",
      # Greater than or equal
      ?] => "≥",
      # Ceiling
      ?{ => "⌈",
      # Ceiling
      ?} => "⌉",
      # Floor
      ?( => "⌊",
      # Floor
      ?) => "⌋",
      # Geometric shapes
      # Diamond
      ?@ => "◆",
      # Square
      ?# => "■",
      # Circle
      ?$ => "●",
      # Circle
      ?% => "○",
      # Circle
      ?& => "◎",
      # Star
      ?* => "★",
      # Plus
      ?+ => "⊕",
      # Minus
      ?- => "⊖",
      # Middle dot
      ?. => "·",
      # Slash
      ?/ => "/"
    }
  end

  @doc """
  Returns the DEC Technical character map.
  """
  def dec_technical_map do
    %{
      # Greek letters
      # Alpha
      ?a => "α",
      # Beta
      ?b => "β",
      # Gamma
      ?g => "γ",
      # Delta
      ?d => "δ",
      # Epsilon
      ?e => "ε",
      # Zeta
      ?z => "ζ",
      # Eta
      ?h => "η",
      # Theta
      ?q => "θ",
      # Iota
      ?i => "ι",
      # Kappa
      ?k => "κ",
      # Lambda
      ?l => "λ",
      # Mu
      ?m => "μ",
      # Nu
      ?n => "ν",
      # Xi
      ?x => "ξ",
      # Omicron
      ?o => "ο",
      # Pi
      ?p => "π",
      # Rho
      ?r => "ρ",
      # Sigma
      ?s => "σ",
      # Tau
      ?t => "τ",
      # Upsilon
      ?u => "υ",
      # Phi
      ?f => "φ",
      # Chi
      ?c => "χ",
      # Psi
      ?y => "ψ",
      # Omega
      ?w => "ω",
      # Mathematical operators
      # Summation
      ?+ => "∑",
      # Product
      ?- => "∏",
      # Integral
      ?* => "∫",
      # Square root
      ?/ => "√",
      # Approximately equal
      ?= => "≈",
      # Less than or equal
      ?< => "≤",
      # Greater than or equal
      ?> => "≥",
      # Not equal
      ?! => "≠",
      # Infinity
      ?@ => "∞",
      # Nabla
      ?# => "∇",
      # Partial derivative
      ?$ => "∂",
      # Proportional to
      ?% => "∝",
      # Logical AND
      ?& => "∧",
      # Logical OR
      ?| => "∨",
      # Logical NOT
      ?~ => "¬",
      # Intersection
      ?^ => "∩",
      # Union
      ?_ => "∪",
      # Element of
      ?` => "∈",
      # Not element of
      ?' => "∉",
      # Subset of
      ?' => "⊂",
      # Superset of
      ?( => "⊃",
      # Subset of or equal to
      ?) => "⊆",
      # Superset of or equal to
      ?[ => "⊇",
      # Not subset of
      ?] => "⊄",
      # Not superset of
      ?{ => "⊅",
      # Not subset of or equal to
      ?} => "⊈",
      # Not superset of or equal to
      ?\\ => "⊉"
    }
  end
end
