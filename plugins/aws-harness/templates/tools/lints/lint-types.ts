// Shared lint types for the harness static scanners.
// Each lint module exports a `lint(template, filePath)` function returning Finding[].
// The runner (run-lints.ts) aggregates findings and prints JSON to stdout.

export type Severity = "critical" | "high" | "medium" | "low";

export interface Finding {
  severity: Severity;
  lint: string;
  resource: string;
  message: string;
}

export interface CfnResource {
  Type: string;
  Properties?: any;
  Metadata?: any;
}

export interface CfnTemplate {
  Resources?: Record<string, CfnResource>;
}

export type LintFn = (template: CfnTemplate, filePath: string) => Finding[];
