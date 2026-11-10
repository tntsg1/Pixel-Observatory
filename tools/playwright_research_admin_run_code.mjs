async page => {
	await page.setViewportSize({ width: 390, height: 844 });
	await page.reload();
	const sections = ["Research Overview", "Participants", "Export", "Feedback"];
	const measurements = [];
	for (const name of sections) {
		await page.getByRole("button", { name, exact: true }).click();
		await page.waitForTimeout(150);
		const size = await page.evaluate(() => ({
			viewport: innerWidth,
			document: document.documentElement.scrollWidth,
			body: document.body.scrollWidth,
		}));
		if (size.document > size.viewport + 1 || size.body > size.viewport + 1) {
			throw new Error(`${name} overflows mobile width: ${JSON.stringify(size)}`);
		}
		measurements.push({ name, ...size });
	}
	return measurements;
}
