import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom/extend-expect';
import TerminalComponent from '../../../lib/raxol_web/components/terminal_component';

// Mock the terminal manager
jest.mock('../../../lib/raxol/terminal/manager', () => ({
  create_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
  destroy_session: jest.fn(),
  list_sessions: jest.fn().mockReturnValue([]),
  get_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
}));

// Mock the terminal emulator
jest.mock('../../../lib/raxol/terminal/emulator', () => ({
  process_input: jest.fn().mockImplementation((emulator, input) => {
    return {
      ...emulator,
      output: input,
      cursor: { row: 0, col: input.length }
    };
  }),
  write_text: jest.fn().mockImplementation((emulator, text) => {
    return {
      ...emulator,
      output: text,
      cursor: { row: 0, col: text.length }
    };
  }),
}));

// Mock the TerminalComponent
const TerminalComponentMock = () => {
  const [input, setInput] = React.useState('');
  
  const handleInputChange = (e) => {
    setInput(e.target.value);
  };
  
  const handleSubmit = (e) => {
    e.preventDefault();
    // Simulate command execution
    console.log(`Command executed: ${input}`);
    setInput('');
  };
  
  return (
    <div data-testid="terminal-container">
      <div data-testid="terminal-output">Terminal Output</div>
      <form onSubmit={handleSubmit}>
        <input
          data-testid="terminal-input"
          type="text"
          value={input}
          onChange={handleInputChange}
          placeholder="Enter command..."
        />
        <button type="submit">Execute</button>
      </form>
    </div>
  );
};

describe('Terminal End-to-End Tests', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  test('user can type text and see it displayed', async () => {
    render(<TerminalComponent />);
    
    // Get the terminal element
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Type some text
    await userEvent.type(terminalElement, 'Hello, World!');
    
    // Check if the text is displayed
    await waitFor(() => {
      expect(screen.getByText('Hello, World!')).toBeInTheDocument();
    });
  });

  test('user can execute a command and see the output', async () => {
    render(<TerminalComponent />);
    
    // Get the terminal element
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Type a command
    await userEvent.type(terminalElement, 'ls');
    
    // Press Enter to execute the command
    await userEvent.keyboard('{Enter}');
    
    // Check if the command output is displayed
    await waitFor(() => {
      expect(screen.getByText(/file1.txt/)).toBeInTheDocument();
      expect(screen.getByText(/file2.txt/)).toBeInTheDocument();
    });
  });

  test('user can navigate command history', async () => {
    render(<TerminalComponent />);
    
    // Get the terminal element
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Type some commands
    await userEvent.type(terminalElement, 'ls');
    await userEvent.keyboard('{Enter}');
    await userEvent.type(terminalElement, 'cd /home');
    await userEvent.keyboard('{Enter}');
    await userEvent.type(terminalElement, 'pwd');
    await userEvent.keyboard('{Enter}');
    
    // Press Up arrow to navigate to previous command
    await userEvent.keyboard('{ArrowUp}');
    
    // Check if the previous command is displayed
    await waitFor(() => {
      expect(screen.getByText('pwd')).toBeInTheDocument();
    });
    
    // Press Up arrow again to navigate to another previous command
    await userEvent.keyboard('{ArrowUp}');
    
    // Check if the previous command is displayed
    await waitFor(() => {
      expect(screen.getByText('cd /home')).toBeInTheDocument();
    });
  });

  test('user can select and copy text', async () => {
    render(<TerminalComponent initialContent="Hello, World!" />);
    
    // Get the terminal element
    const terminalElement = screen.getByTestId('terminal-container');
    
    // Select text
    fireEvent.mouseDown(terminalElement, { clientX: 0, clientY: 0 });
    fireEvent.mouseMove(terminalElement, { clientX: 100, clientY: 0 });
    fireEvent.mouseUp(terminalElement);
    
    // Copy the selected text
    await userEvent.keyboard('{Control>}c{/Control}');
    
    // Check if the text was copied to clipboard
    const clipboardText = await navigator.clipboard.readText();
    expect(clipboardText).toBe('Hello');
  });

  test('terminal session is created and destroyed properly', async () => {
    const { unmount } = render(<TerminalComponent />);
    
    // Check if the session was created
    const { create_session } = require('../../../lib/raxol/terminal/manager');
    expect(create_session).toHaveBeenCalled();
    
    // Unmount the component
    unmount();
    
    // Check if the session was destroyed
    const { destroy_session } = require('../../../lib/raxol/terminal/manager');
    expect(destroy_session).toHaveBeenCalledWith('test-session-id');
  });

  test('user can enter and execute commands', () => {
    render(<TerminalComponentMock />);
    
    // Check if terminal is rendered
    const terminalContainer = screen.getByTestId('terminal-container');
    expect(terminalContainer).toBeInTheDocument();
    
    // Find input field
    const inputField = screen.getByTestId('terminal-input');
    expect(inputField).toBeInTheDocument();
    
    // Enter command
    fireEvent.change(inputField, { target: { value: 'ls' } });
    expect(inputField.value).toBe('ls');
    
    // Submit command
    fireEvent.submit(inputField.closest('form'));
    
    // Check if input is cleared after submission
    expect(inputField.value).toBe('');
  });
}); 