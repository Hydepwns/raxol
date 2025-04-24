# Dialyzer Fix Patterns

## Overview

This document outlines common patterns for addressing Dialyzer warnings in Elixir projects. These patterns were collected during the systematic cleanup of Dialyzer warnings in the Raxol project.

## Prioritization Approach

When addressing Dialyzer warnings, consider the following priority order:

1. **Critical Errors (Highest Priority)**

   - `call_to_missing` - Functions that don't exist or are private
   - `undefined_function` - Similar to above but for direct function calls
   - `pattern_match` - Where patterns can never match
   - `no_return` - Functions that can never return normally

2. **Type System Issues (High Priority)**

   - `invalid_contract` - Typespecs that don't match function implementations
   - `type_violation` - Type inconsistencies in function calls
   - `contract_supertype` - Specs that are too general

3. **Potential Logic/Structure Issues (Medium Priority)**

   - `conflicting_behaviours` - Modules implementing multiple behaviours with conflicting callbacks
   - `unmatched_return` - Returned values that are ignored but might be important
   - `exact_eq` - Comparisons that are always true/false

4. **Code Style/Cleanliness (Lower Priority)**
   - `unused_alias` - Imported modules that aren't used
   - `variable_unused` - Variables defined but not used
   - `pattern_match_cov` - Patterns covered by previous clauses

## Common Fix Patterns

### 1. **Unused Aliases**

- **Solution**: Either remove the unused alias or make use of it where appropriate.
- **Example**: Remove `alias Module.NotUsed` if it's not referenced in the code.

### 2. **Unqualified Module References**

- **Solution**: Add necessary aliases and use them consistently.
- **Example**: Add `alias Project.Submodule.Child` when using `Child` directly.

### 3. **Missing or Private Function Calls**

- **Solution**: Either access struct fields directly or add missing functions.
- **Example**: Replace `Manager.get_position(cursor)` with direct access to `cursor.position`.

### 4. **Non-Standard Functions**

- **Solution**: Replace with standard Elixir equivalents.
- **Example**: Replace `Enum.map_indexed/2` with `Enum.with_index/1 |> Enum.map/2`.

### 5. **Function Signature Mismatches**

- **Solution**: Update function signatures to match how they're called elsewhere.
- **Example**: Ensure optional parameters are handled consistently.

### 6. **Type Specification (@spec) Issues**

- **Solution**: Use fully qualified module names in type specifications.
- **Example**: Change `@spec handle_bel(Emulator.t()) :: Emulator.t()` to `@spec handle_bel(Project.Module.Emulator.t()) :: Project.Module.Emulator.t()`.

### 7. **Enum.min with Default Value Issue**

- **Solution**: Use explicit handling for empty lists instead of default parameter.
- **Example**: Replace `Enum.min(next_stops, width - 1)` with a conditional that checks if the list is empty first.

### 8. **Pattern Matching That Can Never Succeed**

- **Solution**: Use conditional logic (`cond`, `if`) with explicit type checks instead of pattern matching.
- **Example**: Replace pattern matching on struct types with a `cond` block that explicitly checks types using `is_struct/2`.

### 9. **Guard Failures with Complex Types**

- **Solution**: Use safer type checking with `is_struct/2` for struct types instead of relying on pattern guards.
- **Example**: Replace `when buffer === nil` with an explicit `if is_struct(buffer, ScreenBuffer)` check.

### 10. **Robust Error Handling around Problematic Calls**

    - **Solution**: Use try/rescue blocks to handle potential errors from function calls.
    - **Example**: Add try/rescue around calls to services that might be unavailable.

### 11. **Unmatched Return Values**

    - **Solution**: Ensure all expressions that produce values are either assigned to variables or explicitly returned.
    - **Example**: Capture Process.send_after/3 results with `_timer_ref = Process.send_after(...)`.

### 12. **Missing Module References**

    - **Solution**: Create adapter modules that re-export functions from external dependencies.
    - **Example**: Create adapter modules to wrap external dependencies.

### 13. **Recursive Function Call Issues**

    - **Solution**: Avoid implementing functions that recursively call themselves with identical arguments.
    - **Example**: Add termination conditions and ensure progress is made between recursive calls.

### 14. **Contract Warnings**

    - **Solution**: Use `@dialyzer {:nowarn_function, function_name: arity}` to suppress spurious contract warnings.
    - **Example**: Add `@dialyzer {:nowarn_function, resize: 3}` to suppress a contract warning.

### 15. **Handle Clause Mismatch**

    - **Solution**: Make sure functions handle all possible input shapes they might receive.
    - **Example**: Improve functions to handle all possible input formats they may encounter.

### 16. **Guard Failures with Default Parameters**

    - **Solution**: Replace the `params || [default]` pattern with a dedicated helper function or explicit conditions.
    - **Example**: Create helper functions to safely extract parameters with defaults:

    ```elixir
    defp get_param(params, default, index \\ 0) do
      if params == [], do: default, else: Enum.at(params, index, default)
    end
    ```

### 17. **Logger Macro Usage**

    - **Solution**: Always `require Logger` at the top of modules that use Logger macros.
    - **Example**: Add `require Logger` to modules using Logger macros.

### 18. **Invalid Contract in @spec**

    - **Solution**: Ensure all type specifications match the actual function implementations and use fully qualified module names.
    - **Example**: Make sure the types in function specs match the actual parameter types.

### 19. **No Return Function Issues**

    - **Solution**: Fix functions flagged with "no return" by ensuring they can return in all cases.
    - **Example**: Add termination conditions to potentially recursive functions:

    ```elixir
    # Add a max recursion depth parameter with a default
    def process_recursive(emulator, input, max_depth \\ 100)
    def process_recursive(emulator, _, 0), do: emulator # Base case: return when depth exhausted
    def process_recursive(emulator, input, depth) do
      # Process with decremented depth counter
      process_recursive(updated_emulator, rest_input, depth - 1)
    end
    ```

### 20. **Unused Variables**

    - **Solution**: Prefix unused variables with an underscore or remove them if they're not needed.
    - **Example**: Rename `height` to `_height` if it's not used after definition.

### 21. **Parser Pattern Matching Issues**

    - **Solution**: Fix pattern matching issues by ensuring consistent variable handling and fixing underscored variable usage.
    - **Example**: Don't use underscored variables (`_byte`) if you plan to reference them later.

### 22. **Unmatched Returns in Component Code**

    - **Solution**: Ensure component functions properly capture and return their results.
    - **Example**: Capture component function results with variables like `row_result = Layout.row(...)`.

## Using Dialyzer Directives

For cases where Dialyzer produces false positives or when fixes would make code more complex:

```elixir
# For a specific function
@dialyzer {:nowarn_function, function_name: arity}

# For multiple functions
@dialyzer [
  {:nowarn_function, function_name1: arity1},
  {:nowarn_function, function_name2: arity2}
]

# For a specific warning type across the module
@dialyzer {:nowarn, :no_return}
```

Remember that Dialyzer directives should be used sparingly and only when other fixes would compromise code quality.
