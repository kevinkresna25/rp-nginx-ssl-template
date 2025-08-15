document.addEventListener('DOMContentLoaded', () => {
    const y = document.getElementById('y');
    if (y) y.textContent = new Date().getFullYear();
  
    // Kesan kecil saat klik tombol primary
    const primary = document.querySelector('.btn.primary');
    if (primary) {
      primary.addEventListener('click', () => {
        primary.style.transform = 'translateY(1px) scale(0.99)';
        setTimeout(() => (primary.style.transform = ''), 120);
      });
    }
  });
