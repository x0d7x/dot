/**
 * Web Access Extension - Fetch URLs and search the web
 *
 * Registers two custom tools:
 *   - web_fetch:  Fetch and display content from a URL
 *   - web_search: Search the web (uses DuckDuckGo, no API key needed)
 *
 * Usage examples for the LLM:
 *   "Fetch https://example.com and summarize it"
 *   "Search for Go tutorials"
 *   "What's the latest news about Kubernetes?"
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import { Text } from "@earendil-works/pi-tui";

const TIMEOUT = 15_000; // 15 seconds

/** Simple HTML tag stripper for cleaner text output */
function stripHtml(html: string): string {
	return html
		.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
		.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
		.replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, "")
		.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, "")
		.replace(/<header[^>]*>[\s\S]*?<\/header>/gi, "")
		.replace(/<[^>]+>/g, " ")
		.replace(/&amp;/g, "&")
		.replace(/&lt;/g, "<")
		.replace(/&gt;/g, ">")
		.replace(/&quot;/g, '"')
		.replace(/&#39;/g, "'")
		.replace(/&nbsp;/g, " ")
		.replace(/\s+/g, " ")
		.trim();
}

/** Truncate long content for tool results */
function truncateContent(text: string, maxChars = 8000): string {
	if (text.length <= maxChars) return text;
	return text.slice(0, maxChars) + `\n\n... [truncated ${text.length - maxChars} more chars]`;
}

// ── web_fetch tool ──

const FetchParams = Type.Object({
	url: Type.String({ description: "URL to fetch (e.g. https://example.com)" }),
	maxChars: Type.Optional(
		Type.Number({
			description: "Maximum characters to return (default: 8000)",
		}),
	),
});

// ── web_search tool ──

const SearchParams = Type.Object({
	query: Type.String({ description: "Search query" }),
	maxResults: Type.Optional(
		Type.Number({
			description: "Maximum number of search results to return (default: 5)",
		}),
	),
});

export default function (pi: ExtensionAPI) {
	// ═══════════════════════════════════════════
	//  Tool 1: web_fetch - Fetch a URL
	// ═══════════════════════════════════════════
	pi.registerTool({
		name: "web_fetch",
		label: "Web Fetch",
		description:
			"Fetch and read content from a URL. Returns text content (HTML stripped). " +
			"Use this to read documentation, articles, or any web page.",
		promptSnippet: "Fetch content from a URL and read it",
		promptGuidelines: [
			"Use web_fetch when the user provides a URL or asks you to read something from the web.",
			"Prefer fetching documentation, articles, and plain-text content.",
		],
		parameters: FetchParams,

		async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
			const url = params.url.trim();
			const maxChars = params.maxChars ?? 8000;

			// Validate URL
			let parsed: URL;
			try {
				parsed = new URL(url);
				if (!parsed.protocol.startsWith("http")) {
					return {
						content: [{ type: "text", text: `Error: Only HTTP(S) URLs are supported, got: ${parsed.protocol}` }],
						isError: true,
					};
				}
			} catch {
				return {
					content: [{ type: "text", text: `Error: Invalid URL: "${url}"` }],
					isError: true,
				};
			}

			try {
				const response = await fetch(url, {
					signal: AbortSignal.timeout(TIMEOUT),
					headers: {
						"User-Agent":
							"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
						Accept: "text/html,application/json,*/*",
					},
					redirect: "follow",
				});

				if (!response.ok) {
					return {
						content: [
							{
								type: "text",
								text: `Error: HTTP ${response.status} ${response.statusText} for ${url}`,
							},
						],
						isError: true,
					};
				}

				const contentType = response.headers.get("content-type") ?? "";
				let text: string;

				if (contentType.includes("application/json")) {
					// Pretty-print JSON
					const json = await response.json();
					text = JSON.stringify(json, null, 2);
				} else {
					// HTML or plain text - strip HTML tags
					const raw = await response.text();
					text = contentType.includes("text/html") ? stripHtml(raw) : raw;
				}

				const truncated = truncateContent(text, maxChars);
				const meta = `Fetched: ${url}\nContent-Type: ${contentType}\nSize: ${text.length} chars\n---\n\n`;

				return {
					content: [{ type: "text", text: meta + truncated }],
					details: {
						url,
						contentType,
						size: text.length,
						truncated: text.length > maxChars,
					},
				};
			} catch (err) {
				const msg = err instanceof Error ? err.message : String(err);
				// Check for timeout
				if (msg.includes("timeout") || msg.includes("timed out") || msg.includes("abort")) {
					return {
						content: [{ type: "text", text: `Error: Request timed out after ${TIMEOUT / 1000}s for ${url}` }],
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: `Error fetching ${url}: ${msg}` }],
					isError: true,
				};
			}
		},

		renderCall(args, theme, _context) {
			const url = args.url.length > 60 ? args.url.slice(0, 57) + "..." : args.url;
			return new Text(`${theme.fg("toolTitle", theme.bold("fetch "))}${theme.fg("accent", url)}`, 0, 0);
		},

		renderResult(result, { expanded }, theme, _context) {
			const content = result.content[0];
			if (result.isError) {
				const msg = content?.type === "text" ? content.text : "Error";
				return new Text(theme.fg("error", `✗ ${msg}`), 0, 0);
			}

			const details = result.details as { url?: string; size?: number; truncated?: boolean } | undefined;
			const size = details?.size ?? 0;
			const truncated = details?.truncated ?? false;
			const sizeStr = size > 1024 ? `${(size / 1024).toFixed(1)}KB` : `${size}B`;

			let text = theme.fg("success", `✓ ${sizeStr}`);
			if (truncated) text += theme.fg("warning", " [truncated]");
			text += theme.fg("dim", "  (ctrl+e to expand)");

			if (expanded && content?.type === "text") {
				const lines = content.text.split("\n").slice(0, 25);
				for (const line of lines) {
					const trimmed = line.length > 100 ? line.slice(0, 97) + "..." : line;
					text += `\n${theme.fg("dim", trimmed)}`;
				}
				if (content.text.split("\n").length > 25) {
					text += `\n${theme.fg("muted", "... more lines")}`;
				}
			}

			return new Text(text, 0, 0);
		},
	});

	// ═══════════════════════════════════════════
	//  Tool 2: web_search - Search the web
	// ═══════════════════════════════════════════
	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the web using DuckDuckGo. Returns relevant search results with titles, snippets, and URLs. " +
			"Use this to find information, documentation, news, or answers to questions.",
		promptSnippet: "Search the web for information",
		promptGuidelines: [
			"Use web_search when the user asks a question that requires up-to-date information from the web.",
			"Use web_search to find documentation, tutorials, news, or answers to specific questions.",
		],
		parameters: SearchParams,

		async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
			const query = params.query.trim();
			const maxResults = Math.min(params.maxResults ?? 5, 10);

			if (!query) {
				return {
					content: [{ type: "text", text: "Error: Search query cannot be empty" }],
					isError: true,
				};
			}

			try {
				// Use DuckDuckGo's instant answer API for web searches
				// This doesn't require an API key
				const encodedQuery = encodeURIComponent(query);
				const apiUrl = `https://api.duckduckgo.com/?q=${encodedQuery}&format=json&no_html=1&skip_disambig=1`;
				// Also fetch the HTML page for additional results
				const htmlUrl = `https://html.duckduckgo.com/html/?q=${encodedQuery}`;

				const response = await fetch(apiUrl, {
					signal: AbortSignal.timeout(TIMEOUT),
					headers: {
						"User-Agent":
							"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
						Accept: "application/json",
					},
				});

				if (!response.ok) {
					return {
						content: [{ type: "text", text: `Error: Search API returned HTTP ${response.status}` }],
						isError: true,
					};
				}

				const data = (await response.json()) as {
					AbstractText?: string;
					AbstractSource?: string;
					AbstractURL?: string;
					Answer?: string;
					Definition?: string;
					DefinitionSource?: string;
					Results?: Array<{ Text: string; FirstURL: string }>;
					RelatedTopics?: Array<{
						Text?: string;
						FirstURL?: string;
						Topics?: Array<{ Text: string; FirstURL: string }>;
					}>;
				};

				const results: string[] = [];

				// Direct answer (if available)
				if (data.Answer) {
					results.push(`📌 Direct Answer: ${data.Answer}`);
				} else if (data.AbstractText) {
					results.push(`📌 ${data.AbstractText}`);
					if (data.AbstractURL) results.push(`   Source: ${data.AbstractURL}`);
				}

				// Definition
				if (data.Definition && data.Definition !== data.Answer) {
					results.push(`📖 Definition: ${data.Definition}`);
					if (data.DefinitionSource) results.push(`   Source: ${data.DefinitionSource}`);
				}

				// Results from the API
				const apiResults = data.Results ?? [];
				for (const r of apiResults.slice(0, maxResults)) {
					results.push(`🔗 ${r.Text}`);
					results.push(`   ${r.FirstURL}`);
				}

				// Related topics (search results)
				const related = data.RelatedTopics ?? [];
				let topicCount = 0;
				for (const topic of related) {
					if (topicCount >= maxResults) break;
					if (topic.Topics) {
						// Category with sub-topics
						for (const sub of topic.Topics) {
							if (topicCount >= maxResults) break;
							results.push(`🔗 ${sub.Text}`);
							results.push(`   ${sub.FirstURL}`);
							topicCount++;
						}
					} else if (topic.Text) {
						results.push(`🔗 ${topic.Text}`);
						results.push(`   ${topic.FirstURL}`);
						topicCount++;
					}
				}

				// If no results from the API, fall back to scraping HTML results
				if (results.length === 0) {
					const htmlResponse = await fetch(htmlUrl, {
						signal: AbortSignal.timeout(TIMEOUT),
						headers: {
							"User-Agent":
								"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
						},
					});

					if (htmlResponse.ok) {
						const html = await htmlResponse.text();
						// Extract result links from HTML search results
						const linkRegex = /<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
						const snippetRegex = /<a[^>]+class="result__snippet"[^>]*>([\s\S]*?)<\/a>/gi;

						let match: RegExpExecArray | null;
						let htmlCount = 0;

						while ((match = linkRegex.exec(html)) !== null && htmlCount < maxResults) {
								let href = match[1].replace(/&amp;/g, "&");
							// DuckDuckGo redirect URLs - extract the actual URL from uddg parameter
							if (href.includes("uddg=")) {
								try {
									const u = new URL(href.startsWith("//") ? "https:" + href : href);
									const decoded = decodeURIComponent(u.searchParams.get("uddg") ?? "");
									if (decoded) href = decoded;
								} catch { /* keep original */ }
							} else if (href.startsWith("//")) {
								href = "https:" + href;
							}
							const title = stripHtml(match[2]).trim();
							results.push(`🔗 ${title}`);
							results.push(`   ${href}`);
							htmlCount++;
						}
					}
				}

				if (results.length === 0) {
					results.push(`No results found for "${query}". Try a different search term.`);
				}

				const output = `Search results for: "${query}"\n${"-".repeat(50)}\n${results.join("\n\n")}`;
				const truncated = truncateContent(output, maxResults * 600);

				return {
					content: [{ type: "text", text: truncated }],
					details: {
						query,
						resultCount: results.length,
					},
				};
			} catch (err) {
				const msg = err instanceof Error ? err.message : String(err);
				if (msg.includes("timeout") || msg.includes("abort")) {
					return {
						content: [{ type: "text", text: `Error: Search timed out after ${TIMEOUT / 1000}s` }],
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: `Error searching for "${query}": ${msg}` }],
					isError: true,
				};
			}
		},

		renderCall(args, theme, _context) {
			const q = args.query.length > 50 ? args.query.slice(0, 47) + "..." : args.query;
			return new Text(`${theme.fg("toolTitle", theme.bold("search "))}${theme.fg("accent", q)}`, 0, 0);
		},

		renderResult(result, { expanded }, theme, _context) {
			const content = result.content[0];
			if (result.isError) {
				const msg = content?.type === "text" ? content.text : "Error";
				return new Text(theme.fg("error", `✗ ${msg}`), 0, 0);
			}

			const details = result.details as { query?: string; resultCount?: number } | undefined;
			const count = details?.resultCount ?? 0;

			let text = theme.fg("success", `✓ ${count} results`);
			text += theme.fg("dim", "  (ctrl+e to expand)");

			if (expanded && content?.type === "text") {
				const lines = content.text.split("\n").slice(0, 30);
				for (const line of lines) {
					const trimmed = line.length > 120 ? line.slice(0, 117) + "..." : line;
					if (line.startsWith("🔗")) {
						text += `\n${theme.fg("accent", trimmed)}`;
					} else if (line.startsWith("📌")) {
						text += `\n${theme.fg("success", trimmed)}`;
					} else if (line.startsWith("📖")) {
						text += `\n${theme.fg("accent", trimmed)}`;
					} else {
						text += `\n${theme.fg("dim", trimmed)}`;
					}
				}
			}

			return new Text(text, 0, 0);
		},
	});
}
