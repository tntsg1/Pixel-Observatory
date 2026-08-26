async page => {
  return await page.evaluate(() => JSON.stringify({
    sessionRailHidden: document.querySelector(`#game-session-rail`)?.hidden,
    friendsRailHidden: document.querySelector(`#game-friends-rail`)?.hidden,
    compactControlsHidden: document.querySelector(`#game-compact-controls`)?.hidden,
    compactActionsHidden: document.querySelector(`#game-compact-actions`)?.hidden,
    compactActionsDisplay: getComputedStyle(document.querySelector(`#game-compact-actions`)).display,
    rootClasses: document.documentElement.className,
    gameLoaderLoaded: Array.from(document.scripts).some(script => script.src.includes(`game-loader.js`)),
  }));
}
