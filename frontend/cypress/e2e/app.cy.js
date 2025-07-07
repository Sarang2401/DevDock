// frontend/cypress/e2e/app.cy.ts
describe('Frontend Application E2E Tests', () => {
  it('should display "Hello from Backend API!"', () => {
    // Start backend in a separate terminal before running Cypress
    // Or use a tool like `start-server-and-test` in CI
    cy.visit('http://localhost:3000'); // Assuming frontend runs on 3000

    // Wait for the backend status to update
    cy.contains('Backend Status: healthy', { timeout: 10000 }).should('be.visible');

    // Check if the message from the backend is displayed
    cy.contains('Message from Backend: Hello from Backend API!', { timeout: 10000 }).should('be.visible');
  });

  it('should show "healthy" status for the backend', () => {
    cy.visit('http://localhost:3000');
    cy.contains('Backend Status: healthy', { timeout: 10000 }).should('be.visible');
  });
});