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

    // Tow truck
    const truckImg = document.createElement('img');
    truckImg.src = '/img/autumn/tow_truck.png';
    truckImg.id = 'tow-truck';
    document.body.appendChild(truckImg);

    function triggerTimber() {
        // Gust blows the leaves away first
        const allLeaves = document.querySelectorAll('.leaf, .fallen-leaf');
        allLeaves.forEach((leaf) => {
            // Only freeze mid-air leaves to stop them falling
            if (leaf.classList.contains('leaf')) {
                const rect = leaf.getBoundingClientRect();
                leaf.style.animationName = 'none';
                leaf.style.top = rect.top + 'px';
                leaf.style.left = rect.left + 'px';
                leaf.style.bottom = 'auto';
                leaf.style.margin = '0';
            }

            // Scatter slightly in timing
            const delay = Math.random() * 0.4;
            leaf.style.setProperty('animation-delay', `${delay}s`, 'important');

            // Apply custom CSS variables for highly varied physics
            const duration = 1.8 + Math.random() * 1.2; // 1.8s to 3.0s
            leaf.style.setProperty('--gust-duration', `${duration}s`);
            leaf.style.setProperty('--gust-ease', (0.1 + Math.random() * 0.5).toFixed(2));
            leaf.style.setProperty('--gust-ease-out', (0.1 + Math.random() * 0.5).toFixed(2));

            leaf.style.setProperty('--gust-x1', `${-(2 + Math.random() * 10)}vw`);
            leaf.style.setProperty('--gust-y1', `${-5 + Math.random() * 15}vh`);
            leaf.style.setProperty('--gust-r1', `${(Math.random() > 0.5 ? 1 : -1) * (45 + Math.random() * 90)}deg`);

            leaf.style.setProperty('--gust-x2', `${-2 + Math.random() * 10}vw`);
            leaf.style.setProperty('--gust-y2', `${-5 + Math.random() * 15}vh`);
            leaf.style.setProperty('--gust-r2', `${(Math.random() > 0.5 ? 1 : -1) * (180 + Math.random() * 180)}deg`);

            leaf.style.setProperty('--gust-x3', `${-5 + Math.random() * 12}vw`);
            leaf.style.setProperty('--gust-y3', `${-15 + Math.random() * 25}vh`);
            leaf.style.setProperty('--gust-r3', `${(Math.random() > 0.5 ? 1 : -1) * (360 + Math.random() * 180)}deg`);

            leaf.style.setProperty('--gust-y-end', `${-50 + Math.random() * 70}vh`);
            leaf.style.setProperty('--gust-r-end', `${(Math.random() > 0.5 ? 1 : -1) * (1080 + Math.random() * 720)}deg`);

            requestAnimationFrame(() => {
                leaf.classList.add('wind-blown');
            });
            
            setTimeout(() => {
                if (leaf.parentNode) leaf.remove();
            }, (duration + delay) * 1000 + 200);
        });

        activeLeafCount = 0;
        fallenLeaves = [];

        // Wait for the swirling gust to do its thing
        setTimeout(() => {
            treeImg.classList.add('show');

            // Wait for tree to drop (1.5s animation) + a short 0.5s pause
            setTimeout(() => {
                truckImg.style.display = 'block';
                
                // Double rAF to ensure render measurement is correct
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        const truckRect = truckImg.getBoundingClientRect();
                        const truckWidth = truckRect.width || (window.innerWidth * 0.4);
                        const treeRect = treeImg.getBoundingClientRect();
                        const treeTipX = treeRect.right;
                        
                        // We want the truck's right edge to securely overlap the tree tip
                        const overlap = 80;
                        const truckXHook = treeTipX + overlap - window.innerWidth - truckWidth;
                        
                        // Total distance to perfectly drag them both out of screen
                        const pullDist = window.innerWidth * 1.2 + truckWidth;
                        
                        document.documentElement.style.setProperty('--truck-x-hook', `${truckXHook}px`);
                        document.documentElement.style.setProperty('--pull-dist', `${pullDist}px`);
                        
                        truckImg.classList.add('drive-in');
                        
                        // Wait for truck to back in (2.5s) + small coupling pause (0.5s)
                        setTimeout(() => {
                            truckImg.classList.remove('drive-in');
                            truckImg.classList.add('tow-away');
                            treeImg.classList.add('drag-away');
                            
                            // Let the tow complete (4.5s) before clearing
                            setTimeout(() => {
                                treeImg.classList.remove('show', 'drag-away');
                                truckImg.classList.remove('tow-away');
                                truckImg.style.display = 'none';
                            }, 4800);
                        }, 3000);
                    });
                });
            }, 2000);
        }, 1200);
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

    // Allow manual trigger by pressing 'F' (F for Fall/Timber)
    document.addEventListener('keydown', (e) => {
        // Only trigger if 'f' is pressed and the animation is not currently running
        if (e.key.toLowerCase() === 'f' && !treeImg.classList.contains('show')) {
            triggerTimber();
        }
    });
});
