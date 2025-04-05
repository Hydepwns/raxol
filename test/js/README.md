# JavaScript Testing Guidelines

This directory contains the JavaScript testing infrastructure for the Raxol project. The testing setup uses Jest with jsdom environment for browser API simulation.

## Directory Structure

- `__mocks__/`: Contains mock implementations for browser APIs
- `components/`: Tests for React components
- `visual/`: Visual regression tests
- `accessibility/`: Accessibility tests
- `e2e/`: End-to-end tests
- `setup.js`: Jest setup file with browser API mocks
- `test-runner.config.js`: Jest configuration
- `example_test.js`: Example test file

## Running Tests

To run all JavaScript tests:

```bash
npm test
```

To run tests in watch mode:

```bash
npm test -- --watch
```

To run tests with coverage:

```bash
npm test -- --coverage
```

## Writing Tests

### Component Tests

Component tests should be placed in the `components/` directory. Each test file should correspond to a component and follow the naming convention `ComponentName.test.js`.

Example:

```javascript
import { render, screen } from '@testing-library/react';
import Terminal from '../../lib/raxol_web/components/Terminal';

describe('Terminal', () => {
  it('renders without crashing', () => {
    render(<Terminal />);
    expect(screen.getByRole('textbox')).toBeInTheDocument();
  });
});
```

### Visual Regression Tests

Visual regression tests should be placed in the `visual/` directory. These tests capture screenshots of components and compare them against baseline images.

Example:

```javascript
import { render } from '@testing-library/react';
import { toMatchImageSnapshot } from 'jest-image-snapshot';
import Terminal from '../../lib/raxol_web/components/Terminal';

expect.extend({ toMatchImageSnapshot });

describe('Terminal Visual Tests', () => {
  it('matches snapshot', () => {
    const { container } = render(<Terminal />);
    expect(container).toMatchImageSnapshot();
  });
});
```

### Accessibility Tests

Accessibility tests should be placed in the `accessibility/` directory. These tests ensure that components meet accessibility standards.

Example:

```javascript
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import Terminal from '../../lib/raxol_web/components/Terminal';

expect.extend(toHaveNoViolations);

describe('Terminal Accessibility', () => {
  it('has no accessibility violations', async () => {
    const { container } = render(<Terminal />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
```

### End-to-End Tests

End-to-end tests should be placed in the `e2e/` directory. These tests simulate user interactions with the application.

Example:

```javascript
import { test, expect } from '@playwright/test';

test('terminal input and output', async ({ page }) => {
  await page.goto('/');
  await page.fill('[role="textbox"]', 'echo "Hello, World!"');
  await page.keyboard.press('Enter');
  await expect(page.locator('.terminal-output')).toContainText('Hello, World!');
});
```

## Browser API Mocks

The `setup.js` file contains mock implementations for browser APIs that are not available in the Node.js environment. These include:

- `matchMedia`
- `IntersectionObserver`
- `ResizeObserver`

If you need to add more mocks, add them to the `__mocks__/` directory and import them in `setup.js`.

## Best Practices

1. Keep tests focused and isolated
2. Use descriptive test names
3. Follow the Arrange-Act-Assert pattern
4. Mock external dependencies
5. Use test data factories for complex objects
6. Avoid testing implementation details
7. Maintain test coverage above 80% 