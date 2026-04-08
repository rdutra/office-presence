document.addEventListener('DOMContentLoaded', () => {
    const leafContainer = document.createElement('div');
    leafContainer.id = 'leaf-container';
    document.body.appendChild(leafContainer);

    const leavesInfo = ['🍁', '🍂', '🍃', '🍂'];
    const maxActiveLeaves = 40;
    const maxFallenLeaves = 150; // Allow a thicker pile
    let activeLeafCount = 0;
    let fallenLeaves = [];
    
    function createLeaf() {
        if (activeLeafCount >= maxActiveLeaves) return;

        const leaf = document.createElement('div');
        leaf.classList.add('leaf');
        
        // Randomize the leaf emoji
        leaf.innerText = leavesInfo[Math.floor(Math.random() * leavesInfo.length)];
        
        // Randomize horizontal position, duration, and delay
        leaf.style.left = Math.random() * 100 + 'vw';
        const fallDuration = Math.random() * 5 + 6; // 6 to 11s drop
        leaf.style.animationDuration = fallDuration + 's, ' + (Math.random() * 2 + 3) + 's';
        
        // Make them less transparent
        leaf.style.opacity = Math.random() * 0.2 + 0.8; // 0.8 to 1.0 opacity
        leaf.style.fontSize = Math.random() * 36 + 48 + 'px'; // 48px to 84px size
        
        leafContainer.appendChild(leaf);
        activeLeafCount++;
        
        // Immediately add click listener allowing mid-flight pops
        leaf.addEventListener('click', () => popLeaf(leaf));
        
        // Remove leaf after it finishes falling to prevent DOM buildup
        setTimeout(() => {
            if (leaf.parentNode && leaf.classList.contains('leaf')) {
                // Transition to fallen state
                leaf.classList.remove('leaf');
                leaf.classList.add('fallen-leaf');
                leaf.style.animationName = 'none';
                leaf.style.animationDuration = '0s';
                
                // Natural floor accumulation: slight overlap layout
                const pileHeightOffset = Math.random() * 25 - 15; // -15px to +10px from bottom edge
                leaf.style.top = 'auto'; // remove top attribute set by CSS keyframes
                leaf.style.bottom = pileHeightOffset + 'px';
                
                // Rotate to lay somewhat flat like real leaves
                leaf.style.transform = `rotate(${Math.random() * 120 - 60}deg)`;
                
                activeLeafCount--;
                fallenLeaves.push(leaf);
                
                if (fallenLeaves.length > maxFallenLeaves) {
                    const oldest = fallenLeaves.shift();
                    if (oldest && oldest.parentNode) {
                        oldest.remove();
                    }
                }
            }
        }, fallDuration * 1000);
    }
    
    function popLeaf(leaf) {
        if (leaf.classList.contains('popping')) return;
        
        // If falling, freeze current position so it pops in place
        if (leaf.classList.contains('leaf')) {
            const rect = leaf.getBoundingClientRect();
            leaf.style.animationName = 'none';
            leaf.style.top = rect.top + 'px';
            leaf.style.left = rect.left + 'px';
            leaf.classList.remove('leaf');
            activeLeafCount--;
        } else {
            // Remove from tracking array if it was on the floor
            const index = fallenLeaves.indexOf(leaf);
            if (index > -1) fallenLeaves.splice(index, 1);
        }
        
        leaf.classList.add('popping');
        
        setTimeout(() => {
            if (leaf.parentNode) leaf.remove();
        }, 300); // Wait for CSS animation
    }
    
    // Create initially scattered over time
    for (let i = 0; i < 20; i++) {
        setTimeout(createLeaf, Math.random() * 6000);
    }
    
    // Continuously create new ones
    setInterval(createLeaf, 700);

    // Feature: "Timber" style Tree popup from left
    const treeImg = document.createElement('img');
    treeImg.src = '/img/autumn/tree.png';
    treeImg.id = 'tree-timber';
    document.body.appendChild(treeImg);

    function triggerTimber() {
        treeImg.classList.add('show');

        // Hide after an appropriate amount of time
        setTimeout(() => {
            treeImg.classList.remove('show');
        }, 3500);
    }

    function scheduleNextTimber() {
        // Random time between 1 and 4 minutes to pop up
        const minTime = 1 * 60 * 1000;
        const maxTime = 4 * 60 * 1000;
        const nextTime = Math.random() * (maxTime - minTime) + minTime;

        setTimeout(() => {
            triggerTimber();
            scheduleNextTimber();
        }, nextTime);
    }

    // Kick off the schedule after first load
    scheduleNextTimber();
});
