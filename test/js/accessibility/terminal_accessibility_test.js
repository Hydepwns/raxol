import React from 'react';
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import TerminalComponent from '../../../lib/raxol_web/components/terminal_component';

// Extend Jest matchers
expect.extend(toHaveNoViolations);

// Mock the terminal manager
jest.mock('../../../lib/raxol/terminal/manager', () => ({
  create_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
  destroy_session: jest.fn(),
  list_sessions: jest.fn().mockReturnValue([]),
  get_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
}));

describe('Terminal Accessibility Tests', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  test('terminal has no accessibility violations', async () => {
    const { container } = render(<TerminalComponent />);
    
    // Run accessibility check
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  test('terminal has proper ARIA attributes', () => {
    render(<TerminalComponent />);
    
    // Check for proper ARIA attributes
    const terminalElement = screen.getByRole('textbox', { name: /terminal/i });
    expect(terminalElement).toHaveAttribute('aria-label', 'Terminal');
    expect(terminalElement).toHaveAttribute('aria-multiline', 'true');
  });

  test('terminal has proper keyboard navigation', () => {
    render(<TerminalComponent />);
    
    // Check for proper keyboard navigation
    const terminalElement = screen.getByRole('textbox', { name: /terminal/i });
    expect(terminalElement).toHaveAttribute('tabindex', '0');
  });

  test('terminal has proper focus management', () => {
    render(<TerminalComponent />);
    
    // Check for proper focus management
    const terminalElement = screen.getByRole('textbox', { name: /terminal/i });
    terminalElement.focus();
    expect(document.activeElement).toBe(terminalElement);
  });

  test('terminal has proper color contrast', async () => {
    const { container } = render(<TerminalComponent theme="dark" />);
    
    // Run accessibility check with color contrast rules
    const results = await axe(container, {
      rules: {
        'color-contrast': { enabled: true }
      }
    });
    expect(results).toHaveNoViolations();
  });

  test('terminal has proper screen reader support', () => {
    render(<TerminalComponent />);
    
    // Check for proper screen reader support
    const terminalElement = screen.getByRole('textbox', { name: /terminal/i });
    expect(terminalElement).toHaveAttribute('aria-live', 'polite');
  });
}); 