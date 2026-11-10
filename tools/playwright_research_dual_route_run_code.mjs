async page => {
	await page.locator("[data-action=start-text-study]").click();
	await page.waitForSelector("[data-view=text-reading]");
	const modules = await page.locator("[data-archive-node]").count();
	if (modules !== 6) throw new Error(`Expected 6 reading modules, got ${modules}.`);
	await page.locator("[data-action=start-questionnaire]").click();
	await page.setViewportSize({ width: 390, height: 844 });
	const mobileLayout = await page.evaluate(() => ({
		viewport: innerWidth,
		document: document.documentElement.scrollWidth,
	}));
	if (mobileLayout.document > mobileLayout.viewport + 1) {
		throw new Error(`Text questionnaire overflows mobile width: ${JSON.stringify(mobileLayout)}`);
	}
	await page.setViewportSize({ width: 1024, height: 768 });
	const submittedNodes = [];
	for (let group = 0; group < 6; group += 1) {
		await page.waitForSelector("[data-research-survey]");
		const form = page.locator("[data-research-survey]");
		const nodeId = await form.getAttribute("data-node-id");
		const questions = form.locator("[data-question]");
		if (await questions.count() !== 3) throw new Error(`Node ${nodeId} does not have three questions.`);
		for (let index = 0; index < 3; index += 1) {
			const options = questions.nth(index).locator("input[type=radio]");
			if (await options.count() !== 4) throw new Error(`Node ${nodeId}, question ${index + 1} does not have four options.`);
			await options.first().check();
		}
		submittedNodes.push(nodeId);
		await form.locator("button[type=submit]").click();
		if (group < 5) {
			await page.waitForFunction(previous => document.querySelector("[data-research-survey]")?.dataset.nodeId !== previous, nodeId);
		}
	}
	await page.waitForSelector("[data-view=completed]");
	const receipt = (await page.locator(".participant-receipt").innerText()).trim();
	if (!receipt) throw new Error("The completion page has no anonymous participant receipt.");
	return { modules, submittedNodes, receipt };
}
