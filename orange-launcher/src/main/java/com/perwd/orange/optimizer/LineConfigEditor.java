package com.perwd.orange.optimizer;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Edits block-style YAML and .properties files line by line, so comments and layout survive.
 * Only scalar values of keys that already exist are replaced.
 */
final class LineConfigEditor {
    private static final Pattern YAML_KEY = Pattern.compile("^( *)(\"[^\"]+\"|'[^']+'|[^\\s#'\"-][^:#]*?):(?:[ \\t]+(.*))?$");

    record Result(List<String> lines, int changed, int unchanged, java.util.Set<String> found) {
    }

    private LineConfigEditor() {
    }

    static Result editYaml(List<String> lines, Map<String, String> values) {
        List<String> out = new ArrayList<>(lines.size());
        Deque<int[]> indents = new ArrayDeque<>();
        Deque<String> keys = new ArrayDeque<>();
        int changed = 0;
        int unchanged = 0;
        java.util.Set<String> found = new java.util.HashSet<>();
        for (String line : lines) {
            Matcher m = YAML_KEY.matcher(line);
            if (!m.matches()) {
                out.add(line);
                continue;
            }
            int indent = m.group(1).length();
            while (!indents.isEmpty() && indents.peek()[0] >= indent) {
                indents.pop();
                keys.pop();
            }
            String key = unquote(m.group(2).trim());
            indents.push(new int[] {indent});
            keys.push(key);

            String value = m.group(3);
            String path = String.join(".", keys.reversed());
            String wanted = values.get(path);
            if (wanted != null) {
                found.add(path);
            }
            if (wanted == null || value == null || value.isBlank() || isComplex(value)) {
                out.add(line);
                continue;
            }
            if (unquote(stripComment(value).trim()).equals(wanted)) {
                unchanged++;
                out.add(line);
            } else {
                changed++;
                out.add(m.group(1) + m.group(2) + ": " + wanted);
            }
        }
        return new Result(out, changed, unchanged, found);
    }

    static Result editProperties(List<String> lines, Map<String, String> values) {
        List<String> out = new ArrayList<>(lines.size());
        int changed = 0;
        int unchanged = 0;
        java.util.Set<String> found = new java.util.HashSet<>();
        for (String line : lines) {
            int eq = line.indexOf('=');
            if (line.startsWith("#") || eq < 0) {
                out.add(line);
                continue;
            }
            String key = line.substring(0, eq).trim();
            String wanted = values.get(key);
            if (wanted != null) {
                found.add(key);
            }
            if (wanted == null) {
                out.add(line);
            } else if (line.substring(eq + 1).trim().equals(wanted)) {
                unchanged++;
                out.add(line);
            } else {
                changed++;
                out.add(key + "=" + wanted);
            }
        }
        return new Result(out, changed, unchanged, found);
    }

    private static boolean isComplex(String value) {
        String v = value.trim();
        return v.startsWith("|") || v.startsWith(">") || v.startsWith("&") || v.startsWith("*")
                || v.startsWith("#") || v.startsWith("[") || v.startsWith("{");
    }

    private static String stripComment(String value) {
        int hash = value.indexOf(" #");
        return hash < 0 ? value : value.substring(0, hash);
    }

    private static String unquote(String s) {
        if (s.length() >= 2 && (s.startsWith("\"") && s.endsWith("\"") || s.startsWith("'") && s.endsWith("'"))) {
            return s.substring(1, s.length() - 1);
        }
        return s;
    }
}
