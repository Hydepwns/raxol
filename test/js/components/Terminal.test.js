import { render, screen, fireEvent } from '@testing-library/react';
import Terminal from '../../../lib/raxol_web/components/Terminal';

// Mock the terminal emulator
jest.mock('../../../lib/raxol/terminal/emulator', () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => ({
    write: jest.fn(),
    resize: jest.fn(),
    destroy: jest.fn(),
    on: jest.fn(),
    off: jest.fn(),
  })),
}));

describe('Terminal Component', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  it('renders without crashing', () => {
    render(<Terminal />);
    expect(screen.getByRole('textbox')).toBeInTheDocument();
  });

  it('initializes with default props', () => {
    render(<Terminal />);
    expect(screen.getByRole('textbox')).toHaveAttribute('aria-label', 'Terminal');
  });

  it('initializes with custom props', () => {
    render(<Terminal ariaLabel="Custom Terminal" />);
    expect(screen.getByRole('textbox')).toHaveAttribute('aria-label', 'Custom Terminal');
  });

  it('handles keyboard input', () => {
    render(<Terminal />);
    const terminal = screen.getByRole('textbox');
    
    fireEvent.keyDown(terminal, { key: 'a', code: 'KeyA' });
    expect(terminal).toHaveFocus();
  });

  it('handles terminal resize', () => {
    const { container } = render(<Terminal />);
    
    // Simulate window resize
    global.dispatchEvent(new Event('resize'));
    
    // Check if the terminal container has the correct class
    expect(container.firstChild).toHaveClass('terminal-container');
  });

  it('cleans up on unmount', () => {
    const { unmount } = render(<Terminal />);
    
    // Unmount the component
    unmount();
    
    // No assertions needed as we're just checking that unmount doesn't throw
  });
}); 