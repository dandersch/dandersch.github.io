document.querySelectorAll('h2, h3, h4').forEach(item => {
    const children = Array.from(item.parentElement.children)
        .filter(child => child !== item && child.tagName !== 'SCRIPT');
    if (!children.length) { return; }

    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'section-toggle';
    toggle.setAttribute('aria-expanded', 'true');
    toggle.setAttribute('aria-label', `Toggle ${item.textContent.trim()}`);
    item.append(toggle);

    item.addEventListener('click', event => {
        // Heading links still navigate; the button also works with Enter/Space.
        if (event.target.closest('a')) { return; }
        const expanded = toggle.getAttribute('aria-expanded') === 'true';
        children.forEach(child => { child.hidden = expanded; });
        toggle.setAttribute('aria-expanded', String(!expanded));
    });
});

document.querySelectorAll('.nav-link').forEach(link => {
    if (window.location.pathname.split('/')[1] === link.getAttribute('href').slice(1)) {
        link.setAttribute('aria-current', 'page');
    }
});

function XorCoder(key) {
    this.key = key;
}

XorCoder.prototype.decode = function (input) {
    let output = ''; 
    for (let i = 0; i < input.length; i += 2) {
        const hexInput = this.toHex(input, i);
        const hexOutput = hexInput ^ this.key;
        output += String.fromCharCode(hexOutput);
    }
    return output;
}

XorCoder.prototype.toHex = function (text, i) {
    const sequence = text.substr(i, 2);
    return parseInt(sequence, 16);
}

function Email(coder) {
    this.coder = coder;
}

Email.prototype.decodeNodes = function (selector) {
    const nodes = document.querySelectorAll(selector);
    for (let i = 0; i < nodes.length; ++i) {
        this.decodeNode(nodes[i]);
    }
}

Email.prototype.decodeNode = function (node) {
    for (let i = 0; i < node.childNodes.length; ++i) {
        let child = node.childNodes[i];
        if (child.nodeType === Node.ELEMENT_NODE) {
            child = child.firstChild;
        }
        child.nodeValue = this.coder.decode(child.nodeValue);
    }
    node.classList.remove('hidden');
}

window.addEventListener('DOMContentLoaded', function () {
    const coder = new XorCoder(221);
    const email = new Email(coder);
    email.decodeNodes('.email');
});
