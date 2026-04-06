document.addEventListener('DOMContentLoaded', () => {
    const leafContainer = document.createElement('div');
    leafContainer.id = 'leaf-container';
    document.body.appendChild(leafContainer);

    const leavesInfo = ['🍁', '🍂', '🍃', '🍂'];
    const maxLeaves = 40;
    let leafCount = 0;
    
    function createLeaf() {
        if (leafCount >= maxLeaves) return;

        const leaf = document.createElement('div');
        leaf.classList.add('leaf');
        
        // Randomize the leaf emoji
        leaf.innerText = leavesInfo[Math.floor(Math.random() * leavesInfo.length)];
        
        // Randomize horizontal position, duration, and delay
        leaf.style.left = Math.random() * 100 + 'vw';
        leaf.style.animationDuration = Math.random() * 4 + 6 + 's, ' + (Math.random() * 2 + 3) + 's';
        
        // Randomize opacity and size
        leaf.style.opacity = Math.random() * 0.4 + 0.4; // 0.4 to 0.8
        leaf.style.fontSize = Math.random() * 36 + 48 + 'px'; // 48px to 84px
        
        leafContainer.appendChild(leaf);
        leafCount++;
        
        // Remove leaf after it finishes falling to prevent DOM buildup
        setTimeout(() => {
            if (leaf.parentNode) {
                leaf.remove();
                leafCount--;
            }
        }, 10000);
    }
    
    // Create initially scattered over time
    for (let i = 0; i < 20; i++) {
        setTimeout(createLeaf, Math.random() * 6000);
    }
    
    // Continuously create new ones
    setInterval(createLeaf, 700);
});
