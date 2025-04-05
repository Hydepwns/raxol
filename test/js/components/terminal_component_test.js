import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom/extend-expect';
import TerminalComponent from '../../../lib/raxol_web/components/terminal_component';

// Mock the terminal manager
jest.mock('../../../lib/raxol/terminal/manager', () => ({
  create_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
  destroy_session: jest.fn(),
  list_sessions: jest.fn().mockReturnValue([]),
  get_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
}));

describe('TerminalComponent', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  test('renders terminal component', () => {
    render(<TerminalComponent />);
    const terminalElement = screen.getByTestId('terminal-container');
    expect(terminalElement).toBeInTheDocument();
  });

  test('creates a terminal session on mount', () => {
    const { container } = render(<TerminalComponent />);
    expect(container.querySelector('.terminal-session')).toBeInTheDocument();
  });

  test('handles keyboard input', () => {
    render(<TerminalComponent />);
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Simulate keyboard input
    fireEvent.keyDown(terminalElement, { key: 'a', code: 'KeyA' });
    
    // Check if the input was processed
    const inputElement = screen.getByTestId('terminal-input');
    expect(inputElement).toHaveValue('a');
  });

  test('handles terminal resize', () => {
    render(<TerminalComponent />);
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Simulate resize event
    const resizeObserver = new ResizeObserver();
    resizeObserver.observe(terminalElement);
    
    // Trigger resize callback
    const resizeCallback = resizeObserver.observe.mock.calls[0][1];
    resizeCallback({ width: 800, height: 600 });
    
    // Check if the terminal was resized
    expect(terminalElement).toHaveStyle({ width: '800px', height: '600px' });
  });

  test('cleans up resources on unmount', () => {
    const { unmount } = render(<TerminalComponent />);
    
    // Unmount the component
    unmount();
    
    // Check if the session was destroyed
    const { destroy_session } = require('../../../lib/raxol/terminal/manager');
    expect(destroy_session).toHaveBeenCalledWith('test-session-id');
  });
}); 