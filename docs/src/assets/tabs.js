// Initialize tabs when DOM is ready
document.addEventListener('DOMContentLoaded', function () {
    // Find all tab containers
    const tabContainers = document.querySelectorAll('.doc-tabs');

    tabContainers.forEach(container => {
        const labels = container.querySelectorAll('.doc-tabs__label');
        const panels = container.querySelectorAll('.doc-tabs__panel');

        // Activate first tab by default
        if (labels.length > 0 && panels.length > 0) {
            labels[0].classList.add('active');
            panels[0].classList.add('active');
        }

        // Add click handlers to labels
        labels.forEach(label => {
            label.addEventListener('click', function () {
                const tabIndex = this.getAttribute('data-tab');

                // Remove active class from all labels and panels in this container
                labels.forEach(l => l.classList.remove('active'));
                panels.forEach(p => p.classList.remove('active'));

                // Add active class to clicked label and corresponding panel
                this.classList.add('active');
                const targetPanel = container.querySelector(`.doc-tabs__panel[data-tab="${tabIndex}"]`);
                if (targetPanel) {
                    targetPanel.classList.add('active');
                }
            });
        });
    });
});
