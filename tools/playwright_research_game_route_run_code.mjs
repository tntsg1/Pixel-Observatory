async page => {
	await page.evaluate(() => localStorage.clear());
	await page.reload();
	await page.locator("[data-view=fresh-game-entry] a.primary").click();
	await page.waitForURL(url => url.pathname === "/game/" && url.searchParams.get("mode") === "study");
	const required = await page.evaluate(() => {
		const params = new URLSearchParams(location.search);
		return {
			mode: params.get("mode"),
			researchIntro: params.get("research_intro"),
			researchRoute: params.get("research_route"),
			participant: params.get("participant"),
			studyReset: params.get("study_reset"),
		};
	});
	if (required.mode !== "study"
		|| required.researchIntro !== "1"
		|| required.researchRoute !== "field_gameplay"
		|| !required.studyReset) {
		throw new Error(`Original game launch parameters are incomplete: ${JSON.stringify(required)}`);
	}
	if (/Error response|File not found/i.test(await page.locator("body").innerText())) {
		throw new Error("The game route returned an error page.");
	}
	return required;
}
