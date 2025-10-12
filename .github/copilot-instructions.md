# Copilot Instructions for AppSage

This document is intended to guide AI coding agents in understanding the AppSage codebase. It summarizes the essential architecture, developer workflows, and project-specific conventions.

## Big Picture Architecture
- The project is centered around the `appsage.code-workspace` file which organizes workspace settings and configurations.
- Modular components and service boundaries are designed for separation of concerns. Individual modules (e.g., data handling, integration services) should follow patterns observed in existing files.
- Data flows are managed through clearly defined interfaces and configuration files such as `requirements.txt`.

## Developer Workflows
- **Building:** Use VS Code tasks as configured in the workspace or via custom task definitions (e.g., invoking build scripts in PowerShell).
- **Testing:** Execute tests using the integrated VS Code test runner or command-line scripts defined in the repository. Look for test conventions in module documentation.
- **Debugging:** Debug sessions are set up via VS Code launch configurations. Use breakpoints and logging patterns consistent with the project's structure.
- **Dependency Management:** Python dependencies are managed via `requirements.txt`. Additional dependencies might be handled by other package managers if applicable.

## Project-Specific Conventions
- Naming conventions and file structures reflect the patterns in the workspace file and `requirements.txt`.
- Contributions should adhere to the modular design, ensuring new components are self-contained and interact with existing services through defined interfaces.
- Follow examples from key files and maintain consistency in error handling, logging, and configuration management.

## Integration Points & External Dependencies
- External API integrations and service communications should follow explicit contracts as seen in the code.
- Dependency injection and service orchestration patterns observed in critical modules serve as a guideline for implementing new features.

## Additional Guidance
- Review task configurations and any available scripts for build, test, and deployment workflows.
- Continuously update this document as patterns evolve or new components are added.
- Please provide feedback on any unclear sections so that adjustments can be made to better support AI coding agents.
