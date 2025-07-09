// Checkout Analytics - Client-side tracking
class CheckoutAnalytics {
  constructor() {
    this.sessionId = this.getSessionId();
    this.startTime = Date.now();
    this.setupEventListeners();
  }
  
  getSessionId() {
    // Get Rails session ID from meta tag or generate one
    const metaTag = document.querySelector('meta[name="session-id"]');
    return metaTag ? metaTag.content : this.generateSessionId();
  }
  
  generateSessionId() {
    return 'session_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
  }
  
  setupEventListeners() {
    // Track checkout button clicks
    document.addEventListener('click', (e) => {
      if (e.target.matches('a[href*="new_order"]') || 
          e.target.matches('.checkout-btn') || 
          e.target.closest('.checkout-btn')) {
        this.trackEvent('checkout_button_clicked', {
          button_text: e.target.textContent.trim(),
          page_url: window.location.href
        });
      }
      
      // Track "Add to Cart" clicks
      if (e.target.matches('a[href*="cart/add"]') || 
          e.target.closest('a[href*="cart/add"]')) {
        const productId = this.extractProductId(e.target.href || e.target.closest('a').href);
        this.trackEvent('add_to_cart_clicked', {
          product_id: productId,
          page_url: window.location.href
        });
      }
    });
    
    // Track form abandonment
    const checkoutForm = document.querySelector('form[action*="orders"]');
    if (checkoutForm) {
      this.trackFormAbandonment(checkoutForm);
    }
    
    // Track page visibility changes (potential abandonment)
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && this.isCheckoutPage()) {
        this.trackEvent('checkout_page_hidden', {
          time_on_page: Date.now() - this.startTime,
          page_url: window.location.href
        });
      }
    });
    
    // Track before page unload (abandonment)
    window.addEventListener('beforeunload', () => {
      if (this.isCheckoutPage()) {
        this.trackEvent('checkout_page_abandoned', {
          time_on_page: Date.now() - this.startTime,
          page_url: window.location.href
        }, true); // Synchronous for page unload
      }
    });
  }
  
  trackFormAbandonment(form) {
    let formStarted = false;
    let fieldsInteracted = [];
    
    form.addEventListener('focusin', (e) => {
      if (!formStarted) {
        formStarted = true;
        this.trackEvent('checkout_form_started', {
          form_id: form.id || 'checkout_form'
        });
      }
      
      if (!fieldsInteracted.includes(e.target.name)) {
        fieldsInteracted.push(e.target.name);
      }
    });
    
    form.addEventListener('submit', () => {
      this.trackEvent('checkout_form_submitted', {
        fields_completed: fieldsInteracted.length,
        time_to_complete: Date.now() - this.startTime
      });
    });
    
    // Track field-level abandonment
    form.querySelectorAll('input, select, textarea').forEach(field => {
      field.addEventListener('blur', () => {
        if (field.value.trim() === '') {
          this.trackEvent('checkout_field_abandoned', {
            field_name: field.name,
            field_type: field.type
          });
        }
      });
    });
  }
  
  trackEvent(eventName, data = {}, sync = false) {
    const payload = {
      event: eventName,
      session_id: this.sessionId,
      timestamp: new Date().toISOString(),
      user_agent: navigator.userAgent,
      ...data
    };
    
    // Send to Rails backend
    const url = '/analytics/track';
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify(payload)
    };
    
    if (sync) {
      // Use sendBeacon for synchronous tracking (page unload)
      navigator.sendBeacon(url, JSON.stringify(payload));
    } else {
      fetch(url, options).catch(err => console.warn('Analytics tracking failed:', err));
    }
  }
  
  isCheckoutPage() {
    return window.location.pathname.includes('/orders/') || 
           window.location.pathname.includes('/cart');
  }
  
  extractProductId(href) {
    const match = href.match(/\/cart\/add\/(\d+)/);
    return match ? match[1] : null;
  }
  
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.content : '';
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  new CheckoutAnalytics();
});
