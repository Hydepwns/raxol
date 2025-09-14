;; Treesitter queries for Raxol-specific patterns

;; Component definitions
(call
  target: (identifier) @_use
  (arguments
    (alias
      name: (identifier) @component.name
      (#match? @component.name "^Raxol\\.UI\\.Components"))))
(#eq? @_use "use")

;; Lifecycle methods
(call
  target: (identifier) @lifecycle.method
  (#match? @lifecycle.method "^(init|mount|update|render|handle_event|unmount)$"))

;; Component function definitions
(function
  name: (identifier) @lifecycle.function
  (#match? @lifecycle.function "^(init|mount|update|render|handle_event|unmount)$"))

;; Event handlers
(pair
  key: (atom) @event.handler
  (#match? @event.handler "^on_\\w+"))

;; Component props
(map
  (pair
    key: (atom) @prop.key
    value: (_) @prop.value))

;; UI elements
(call
  target: (identifier) @ui.element
  (#match? @ui.element "^(button|text_input|table|modal|column|row|text)$"))

;; Raxol module imports
(alias
  module: (identifier) @module.raxol
  (#match? @module.raxol "^Raxol"))

;; Framework-specific patterns
(call
  target: (identifier) @_use
  (arguments
    (alias
      name: (identifier) @framework.ui
      (#match? @framework.ui "^Raxol\\.UI$"))))
(#eq? @_use "use")

;; TEA (The Elm Architecture) pattern matching
(case
  condition: (struct
    name: (alias
      module: (identifier) @_event
      name: (identifier) @_event_struct))
  (#eq? @_event "Event")
  (#eq? @_event_struct "Event"))

;; Component state updates
(call
  target: (identifier) @update.function
  (arguments
    (struct
      name: (identifier) @update.state
      (#match? @update.state "model|state"))))
(#eq? @update.function "update")