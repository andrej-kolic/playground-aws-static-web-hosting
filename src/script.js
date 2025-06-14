// Smooth scrolling for navigation links
document.addEventListener('DOMContentLoaded', function() {
    const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
    
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetSection = document.querySelector(targetId);
            
            if (targetSection) {
                const headerHeight = document.querySelector('header').offsetHeight;
                const targetPosition = targetSection.offsetTop - headerHeight;
                
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
});

// Show message function for the CTA button
function showMessage() {
    alert('Welcome! This is a demo static website hosted on AWS.\n\nFeatures:\n- S3 Static Hosting\n- CloudFront CDN\n- SSL Certificate\n- Custom Domain\n- GitHub Actions CI/CD');
}

// Add scroll effect to header
window.addEventListener('scroll', function() {
    const header = document.querySelector('header');
    
    if (window.scrollY > 100) {
        header.style.background = 'rgba(44, 62, 80, 0.95)';
        header.style.backdropFilter = 'blur(10px)';
    } else {
        header.style.background = '#2c3e50';
        header.style.backdropFilter = 'none';
    }
});

// Add animation on scroll for sections
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver(function(entries) {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe sections for animation
document.addEventListener('DOMContentLoaded', function() {
    const sections = document.querySelectorAll('.about, .contact');
    
    sections.forEach(section => {
        section.style.opacity = '0';
        section.style.transform = 'translateY(30px)';
        section.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(section);
    });
});

// Add loading animation
window.addEventListener('load', function() {
    document.body.classList.add('loaded');
});

// Console message for developers
console.log(
    '%cWelcome to the Static Web Hosting Demo!',
    'color: #3498db; font-size: 20px; font-weight: bold;'
);

console.log(
    'This project demonstrates:\n' +
    '🚀 AWS S3 Static Hosting\n' +
    '⚡ CloudFront CDN\n' +
    '🔒 SSL Certificate\n' +
    '🏗️ Infrastructure as Code\n' +
    '🔄 CI/CD with GitHub Actions'
);

