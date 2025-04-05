import React from 'react';
import { render } from '@testing-library/react';
import { toMatchImageSnapshot } from 'jest-image-snapshot';
import TerminalComponent from '../../../lib/raxol_web/components/terminal_component';

// Extend Jest matchers
expect.extend({ toMatchImageSnapshot });

// Mock the terminal manager
jest.mock('../../../lib/raxol/terminal/manager', () => ({
  create_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
  destroy_session: jest.fn(),
  list_sessions: jest.fn().mockReturnValue([]),
  get_session: jest.fn().mockReturnValue({ id: 'test-session-id' }),
}));

// Mock the TerminalComponent
const TerminalComponentMock = () => {
  return (
    <div style={{ 
      backgroundColor: '#000', 
      color: '#fff', 
      padding: '10px', 
      fontFamily: 'monospace',
      width: '500px',
      height: '300px'
    }}>
      <div>Terminal Component</div>
      <div>$ ls</div>
      <div>file1.txt  file2.txt  directory1</div>
      <div>$ _</div>
    </div>
  );
};

describe('Terminal Visual Tests', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  test('terminal default appearance', async () => {
    const { container } = render(<TerminalComponentMock />);
    
    // Wait for the terminal to render
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Take a screenshot of the terminal
    const screenshot = await page.screenshot();
    
    // Compare with the snapshot
    expect(screenshot).toMatchImageSnapshot();
  });

  test('terminal with custom theme', async () => {
    const { container } = render(
      <TerminalComponent theme="dark" fontSize={14} fontFamily="monospace" />
    );
    
    // Wait for the terminal to render
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Take a screenshot and compare with snapshot
    const terminalElement = container.querySelector('.terminal-container');
    expect(terminalElement).toMatchImageSnapshot();
  });

  test('terminal with content', async () => {
    const { container } = render(<TerminalComponent initialContent="Hello, World!" />);
    
    // Wait for the terminal to render
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Take a screenshot and compare with snapshot
    const terminalElement = container.querySelector('.terminal-container');
    expect(terminalElement).toMatchImageSnapshot();
  });

  test('terminal with cursor', async () => {
    const { container } = render(<TerminalComponent showCursor={true} />);
    
    // Wait for the terminal to render
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Take a screenshot and compare with snapshot
    const terminalElement = container.querySelector('.terminal-container');
    expect(terminalElement).toMatchImageSnapshot();
  });

  test('terminal with selection', async () => {
    const { container } = render(
      <TerminalComponent 
        initialContent="Hello, World!" 
        selection={{ start: { row: 0, col: 0 }, end: { row: 0, col: 5 } }}
      />
    );
    
    // Wait for the terminal to render
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Take a screenshot and compare with snapshot
    const terminalElement = container.querySelector('.terminal-container');
    expect(terminalElement).toMatchImageSnapshot();
  });
}); 