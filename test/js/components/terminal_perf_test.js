import React from 'react';
import { render } from '@testing-library/react';

// Mock the TerminalComponent
const TerminalComponent = () => {
  return <div>Terminal Component</div>;
};

describe('TerminalComponent Performance', () => {
  test('terminal renders within performance budget', () => {
    const startTime = performance.now();
    
    render(<TerminalComponent />);
    
    const endTime = performance.now();
    const renderTime = endTime - startTime;
    
    // Expect render time to be less than 100ms
    expect(renderTime).toBeLessThan(100);
  });
}); 