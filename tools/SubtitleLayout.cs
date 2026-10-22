using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

// Playback copies only: the original ASS and its special typesetting stay intact.
public static class SubtitleLayout
{
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
    sealed class Event
    {
        public int Line, Align, Lang, Part;
        public bool Grouped;
        public double Start, End, Height, Margin, Gap;
        public string[] Fields;
        public Dictionary<string, int> Map;
        public string Get(string key) { return Fields[Map[key]]; }
        public void Set(string key, string value) { Fields[Map[key]] = value; }
    }
    static Dictionary<string, int> Map(string line)
    {
        return line.Substring(line.IndexOf(':') + 1).Split(',')
            .Select((v, i) => new { Name = v.Trim(), Index = i })
            .ToDictionary(v => v.Name, v => v.Index, StringComparer.OrdinalIgnoreCase);
    }
    static double Num(string s) { return double.Parse(s, Inv); }
    static string Fmt(double n) { return n.ToString("0.###", Inv); }
    static double Time(string s) { return TimeSpan.Parse(s, Inv).TotalSeconds; }
    static bool Matches(FontFamily family, string name)
    {
        return new[] { 0, 1033, 2052, 1028, 1041 }.Any(id => family.GetName(id).Equals(name, StringComparison.OrdinalIgnoreCase));
    }
    static bool HasKana(string s) { return Regex.IsMatch(s, "[\\u3040-\\u30ff]"); }
    static int StyleLanguage(string style)
    {
        if (Regex.IsMatch(style, "日文|日语|日本語|英文|英语|English", RegexOptions.IgnoreCase)) return 2;
        if (Regex.IsMatch(style, "中文|简体|繁体|汉语")) return 1;
        if (Regex.IsMatch(style, @"(?:^|[_\- ])(?:JP|JPN|JA|EN|ENG)(?:$|[_\- ])", RegexOptions.IgnoreCase)) return 2;
        if (Regex.IsMatch(style, @"(?:^|[_\- ])(?:CN|CHS|CHT|SC|TC|ZH)(?:$|[_\- ])", RegexOptions.IgnoreCase)) return 1;
        return 0;
    }
    static string Visible(string text) { return Regex.Replace(text, @"\{[^}]*\}", ""); }
    static bool Han(string text) { return Regex.IsMatch(text, "[\\u3400-\\u9fff]"); }
    static bool ChineseEvidence(string text) { return Regex.IsMatch(text, "[这這们們吗嗎说說对對让讓给給还還]|你好|您好|谢谢|謝謝|再见|再見"); }
    static int TextLanguage(string text)
    {
        text = Visible(text);
        if (HasKana(text)) return 2;
        if (Han(text)) return Regex.IsMatch(text, @"[a-zA-Z]") && Regex.IsMatch(text, @"[/／|]|[a-zA-Z]+\s+[a-zA-Z]+") ? -1 : 1;
        return Regex.IsMatch(text, "[a-zA-Z]{2}") ? 2 : 0;
    }
    static string[] SplitText(string text)
    {
        var parts = text.Split(new[] { @"\N" }, StringSplitOptions.None);
        string tags = "";
        for (int i = 0; i < parts.Length; i++)
        {
            string current = parts[i];
            parts[i] = tags + current;
            tags += string.Concat(Regex.Matches(current, @"\{[^}]*\}").Cast<Match>().Select(m => m.Value));
        }
        return parts;
    }
    static bool Ordinary(string text, string effect, int align)
    {
        if (effect.Trim() != "" || (align != 2 && align != 8)) return false;
        // Only inline colour, weight and simple border tags are safe to reflow.
        foreach (Match block in Regex.Matches(text, @"\{[^}]*\}"))
        {
            string rest = Regex.Replace(block.Value, @"\\(?:[1-4]?c&H[0-9a-f]*&?|(?:[1-4]a|alpha)&H[0-9a-f]*&?|[bius]-?\d+|q[0-3]|(?:bord|shad|blur|be)[0-9.]+)", "", RegexOptions.IgnoreCase);
            if (rest.Trim('{', '}', ' ') != "") return false;
        }
        return !Regex.IsMatch(text, @"\{[^}]*$|^[^{]*\}");
    }
    static List<string> Tokens(string text)
    {
        var tokens = new List<string>();
        for (int i = 0; i < text.Length;)
        {
            if (text[i] == '{')
            {
                int end = text.IndexOf('}', i);
                if (end < 0) throw new FormatException("Unclosed ASS tag");
                tokens.Add(text.Substring(i, end - i + 1)); i = end + 1;
            }
            else if (text[i] == '\\' && i + 1 < text.Length && "Nnh".IndexOf(text[i + 1]) >= 0)
            { tokens.Add(text.Substring(i, 2)); i += 2; }
            else
            { string t = StringInfo.GetNextTextElement(text, i); tokens.Add(t); i += t.Length; }
        }
        return tokens;
    }
    static string Plain(IEnumerable<string> tokens)
    {
        return string.Concat(tokens.Where(t => !t.StartsWith("{")))
            .Replace(@"\h", "\u00a0").Replace(@"\n", " ");
    }
    static bool CanBreak(string a, string b)
    {
        if (a == @"\h" || b == @"\h" || a.StartsWith("{") || b.StartsWith("{")) return false;
        if ("、。，．！？：；)]}）】》」』…ー".Contains(b)) return false;
        if ("([{（【《「『".Contains(a)) return false;
        if (string.IsNullOrWhiteSpace(a) || string.IsNullOrWhiteSpace(b)) return true;
        return Regex.IsMatch(a + b, "[\\u2e80-\\u9fff\\uf900-\\ufaff]");
    }
    static double Width(Graphics g, Font font, StringFormat format, string text, double scaleX, double spacing)
    {
        // shortcut: GDI and libass metrics differ; reserve 12% width and verify real renders before reducing it.
        int characters = new StringInfo(text).LengthInTextElements;
        return (g.MeasureString(text, font, int.MaxValue, format).Width + Math.Max(0, characters - 1) * spacing) * scaleX * 1.12;
    }
    static string Wrap(string text, Graphics g, Font font, double width, double scaleX, double spacing, out int lines)
    {
        var tokens = Tokens(text);
        var output = new List<string>();
        var line = new List<string>();
        lines = 1;
        using (var format = (StringFormat)StringFormat.GenericTypographic.Clone())
        {
            format.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
            foreach (string token in tokens)
            {
                if (token == @"\N")
                { output.AddRange(line); output.Add(@"\N"); line.Clear(); lines++; continue; }
                line.Add(token);
                if (token.StartsWith("{") || Width(g, font, format, Plain(line), scaleX, spacing) <= width) continue;
                int split = -1;
                for (int j = line.Count - 1; j > 0; j--)
                    if (CanBreak(line[j - 1], line[j])) { split = j; break; }
                // An overlong unbroken word still needs a hard break.
                if (split < 1) split = line.Count - 1;
                while (split > 0 && line[split - 1].StartsWith("{")) split--;
                if (split == 0) continue;
                output.AddRange(line.Take(split)); output.Add(@"\N");
                line = line.Skip(split).ToList(); lines++;
            }
            output.AddRange(line);
        }
        return string.Concat(output).Replace(@"\q2", @"\q0");
    }
    public static int[] Process(string input, string output, double scale, string fallback, string[] fontDirs, Dictionary<string, string> plainStyle)
    {
        if (scale < 0.1 || scale > 10 || double.IsNaN(scale)) throw new ArgumentOutOfRangeException("scale");
        var lines = File.ReadAllLines(input, Encoding.UTF8).ToList();
        var styles = new Dictionary<string, string[]>(StringComparer.Ordinal);
        Dictionary<string, int> sm = null, em = null;
        int styleEnd = -1, skipped = 0, unsafeBilingual = 0;
        double resX = 0, resY = 0;
        int wrapStyle = 0;
        string section = "";
        for (int i = 0; i < lines.Count; i++)
        {
            string line = lines[i].Trim();
            if (line.StartsWith("["))
            { if (section == "[V4+ Styles]") styleEnd = i; section = line; }
            if (section == "[Script Info]")
            {
                if (line.StartsWith("PlayResX:", StringComparison.OrdinalIgnoreCase)) resX = Num(line.Split(':')[1]);
                if (line.StartsWith("PlayResY:", StringComparison.OrdinalIgnoreCase)) resY = Num(line.Split(':')[1]);
                if (line.StartsWith("WrapStyle:", StringComparison.OrdinalIgnoreCase)) wrapStyle = (int)Num(line.Split(':')[1]);
            }
            if (section == "[V4+ Styles]" && line.StartsWith("Format:", StringComparison.OrdinalIgnoreCase)) sm = Map(line);
            if (section == "[V4+ Styles]" && line.StartsWith("Style:", StringComparison.OrdinalIgnoreCase))
            {
                if (sm == null) throw new FormatException("Missing ASS style Format");
                string[] fields = line.Substring(6).TrimStart().Split(',');
                if (fields.Length != sm.Count) throw new FormatException("Invalid ASS style fields");
                styles.Add(fields[sm["Name"]], fields);
            }
            if (section == "[Events]" && line.StartsWith("Format:", StringComparison.OrdinalIgnoreCase)) em = Map(line);
        }
        if (sm == null || em == null || styleEnd < 0 || resX <= 0 || resY <= 0 || em["Text"] != em.Count - 1)
            throw new FormatException("ASS requires V4+ Styles, Events and explicit PlayResX/Y with Text last");
        if (plainStyle != null)
        {
            resX = Num(plainStyle["PlayResX"]); resY = 720;
            for (int i = 0; i < lines.Count; i++)
            {
                if (Regex.IsMatch(lines[i], @"^(?:PlayRes|LayoutRes)X:", RegexOptions.IgnoreCase)) lines[i] = "PlayResX: " + Fmt(resX);
                if (Regex.IsMatch(lines[i], @"^(?:PlayRes|LayoutRes)Y:", RegexOptions.IgnoreCase)) lines[i] = "PlayResY: 720";
                if (!lines[i].StartsWith("Style:", StringComparison.OrdinalIgnoreCase)) continue;
                var style = styles[lines[i].Substring(6).TrimStart().Split(',')[sm["Name"]]];
                foreach (var value in plainStyle) if (sm.ContainsKey(value.Key)) style[sm[value.Key]] = value.Value;
                lines[i] = "Style: " + string.Join(",", style);
            }
        }
        var raw = new List<Event>();
        for (int i = 0; i < lines.Count; i++)
        {
            if (!lines[i].StartsWith("Dialogue:", StringComparison.OrdinalIgnoreCase)) continue;
            string[] fields = lines[i].Substring(9).TrimStart().Split(new[] { ',' }, em.Count);
            if (fields.Length != em.Count) throw new FormatException("Invalid ASS event fields");
            var ev = new Event { Line = i, Fields = fields, Map = em };
            string[] style;
            if (!styles.TryGetValue(ev.Get("Style"), out style)) throw new FormatException("Unknown ASS style: " + ev.Get("Style"));
            ev.Align = (int)Num(style[sm["Alignment"]]);
            if (!Ordinary(ev.Get("Text"), ev.Get("Effect"), ev.Align) || style[sm["Fontname"]].StartsWith("@") || Num(style[sm["Angle"]]) != 0)
            {
                var roles = SplitText(ev.Get("Text")).Select(TextLanguage).ToArray();
                if (plainStyle != null && roles.Contains(1) && roles.Contains(2)) unsafeBilingual++;
                skipped++; continue;
            }
            string text = ev.Get("Text");
            ev.Set("Text", text.Replace(@"\n", wrapStyle == 2 || text.Contains(@"\q2") ? @"\N" : " "));
            ev.Start = Time(ev.Get("Start")); ev.End = Time(ev.Get("End"));
            raw.Add(ev);
        }
        bool chineseEvidence = raw.Any(e => StyleLanguage(e.Get("Style")) == 1 || ChineseEvidence(Visible(e.Get("Text"))));
        var patterns = new Dictionary<string, int[]>();
        var sharedStyles = new HashSet<string>();
        foreach (Event ev in raw)
        {
            string[] parts = SplitText(ev.Get("Text"));
            int[] roles = parts.Select(TextLanguage).ToArray();
            if (parts.Length < 2 || StyleLanguage(ev.Get("Style")) == 2 || !roles.Contains(1) || !roles.Contains(2)) continue;
            if (!chineseEvidence && !parts.Any(p => !Han(Visible(p)) && !HasKana(Visible(p)) && TextLanguage(p) == 2)) continue;
            sharedStyles.Add(ev.Get("Style"));
            string key = ev.Get("Style") + "|" + parts.Length;
            int[] previous;
            if (patterns.TryGetValue(key, out previous))
            {
                for (int n = 0; n < roles.Length; n++) if (roles[n] > 0 && previous[n] > 0 && roles[n] != previous[n]) previous[n] = -1;
            }
            else patterns.Add(key, roles);
        }
        var events = new List<Event>();
        foreach (Event ev in raw)
        {
            string[] parts = SplitText(ev.Get("Text"));
            int[] roles;
            bool pattern = patterns.TryGetValue(ev.Get("Style") + "|" + parts.Length, out roles) && roles.Contains(1) && roles.Contains(2) && !roles.Contains(-1);
            int[] localRoles = parts.Select(TextLanguage).ToArray();
            bool mixed = parts.Length > 1 && StyleLanguage(ev.Get("Style")) != 2 && localRoles.Contains(1) && localRoles.Contains(2)
                && (chineseEvidence || parts.Any(p => !Han(Visible(p)) && !HasKana(Visible(p)) && TextLanguage(p) == 2));
            if (mixed || pattern)
            {
                if (!pattern) roles = localRoles;
                int lastRole = -99;
                Event block = null;
                for (int n = 0; n < parts.Length; n++)
                {
                    int role = TextLanguage(parts[n]);
                    if (role == 0 || (role == 1 && roles[n] == 2 && !ChineseEvidence(Visible(parts[n])))) role = roles[n];
                    if (role == lastRole) block.Set("Text", block.Get("Text") + @"\N" + parts[n]);
                    else
                    {
                        block = new Event { Line = ev.Line, Part = n, Align = ev.Align, Lang = role, Grouped = true,
                            Start = ev.Start, End = ev.End, Fields = (string[])ev.Fields.Clone(), Map = em };
                        block.Set("Text", parts[n]); events.Add(block); lastRole = role;
                    }
                }
            }
            else
            {
                ev.Lang = sharedStyles.Contains(ev.Get("Style")) ? 0 : StyleLanguage(ev.Get("Style"));
                if (ev.Lang == 0) ev.Lang = TextLanguage(ev.Get("Text").Replace(@"\N", " "));
                if (Han(Visible(ev.Get("Text"))) && Regex.IsMatch(Visible(ev.Get("Text")), @"[a-zA-Z]") && Regex.IsMatch(Visible(ev.Get("Text")), @"[/／|]")) ev.Lang = -1;
                events.Add(ev);
            }
        }
        bool bilingual = events.Any(c => c.Lang == 1 && events.Any(f => f.Lang == 2 && f.Align == c.Align && f.Start < c.End && c.Start < f.End));
        bool japanese = raw.Any(e => HasKana(Visible(e.Get("Text"))));
        // shortcut: unlabelled Han-only cues need language metadata for certainty; keep 1x and report them in Japanese bilingual files.
        if (bilingual && japanese)
            foreach (Event ev in events.Where(e => !e.Grouped && e.Lang == 1 && (StyleLanguage(e.Get("Style")) == 0 || sharedStyles.Contains(e.Get("Style"))) && !ChineseEvidence(Visible(e.Get("Text"))))) ev.Lang = 0;
        int uncertain = events.Count(e => e.Lang < 0 || (bilingual && e.Lang == 0));
        if (plainStyle != null && skipped > 0 && (bilingual || uncertain > 0 || unsafeBilingual > 0))
            throw new InvalidOperationException("SRT contains unsupported positioning/font-size/effect tags; original track retained");
        if (plainStyle != null && !bilingual && uncertain == 0) return new[] { 0, skipped, 0, 0, 0 };
        var newStyles = new List<string>();
        using (var fonts = new PrivateFontCollection())
        using (var bmp = new Bitmap(1, 1))
        using (var g = Graphics.FromImage(bmp))
        {
            foreach (string dir in fontDirs.Reverse())
                if (Directory.Exists(dir))
                    foreach (string f in Directory.GetFiles(dir).Where(f => Regex.IsMatch(f, @"\.(ttf|otf|ttc|otc)$", RegexOptions.IgnoreCase)))
                        fonts.AddFontFile(f);
            var families = fonts.Families.Concat(FontFamily.Families).ToArray();
            FontFamily defaultFamily = families.FirstOrDefault(f => Matches(f, fallback));
            if (defaultFamily == null) throw new InvalidOperationException("Fallback font unavailable: " + fallback);
            foreach (Event ev in events)
            {
                string[] orig = styles[ev.Get("Style")];
                string[] style = (string[])orig.Clone();
                string name = "__mpv_layout_" + ev.Line + "_" + ev.Part;
                while (styles.ContainsKey(name)) name += "_";
                double effectiveScale = ev.Lang < 0 || (bilingual && ev.Lang != 1) ? 1 : scale;
                double size = Num(style[sm["Fontsize"]]) * effectiveScale;
                double sx = Num(style[sm["ScaleX"]]) / 100, sy = Num(style[sm["ScaleY"]]) / 100;
                if (size <= 0 || sx <= 0 || sy <= 0) throw new FormatException("Invalid ASS font size/scale");
                string familyName = style[sm["Fontname"]].TrimStart('@');
                FontFamily family = families.FirstOrDefault(f => Matches(f, familyName)) ?? defaultFamily;
                FontStyle weight = FontStyle.Regular;
                if (Num(style[sm["Bold"]]) != 0 || Regex.IsMatch(ev.Get("Text"), @"\\b(?:1|[6-9]00)")) weight |= FontStyle.Bold;
                if (Num(style[sm["Italic"]]) != 0 || ev.Get("Text").Contains(@"\i1")) weight |= FontStyle.Italic;
                if (!family.IsStyleAvailable(weight)) weight = FontStyle.Regular;
                if (!family.IsStyleAvailable(weight)) weight = family.IsStyleAvailable(FontStyle.Bold) ? FontStyle.Bold : FontStyle.Italic;
                double left = Num(ev.Get("MarginL")), right = Num(ev.Get("MarginR"));
                if (left == 0) left = Num(style[sm["MarginL"]]);
                if (right == 0) right = Num(style[sm["MarginR"]]);
                double outline = Num(style[sm["Outline"]]) * effectiveScale;
                int count;
                // libass sizes the ascender+descender, whereas GDI sizes the em square.
                double emSize = size * family.GetEmHeight(weight) / (family.GetCellAscent(weight) + family.GetCellDescent(weight));
                using (var font = new Font(family, (float)emSize, weight, GraphicsUnit.Pixel))
                {
                    string text = Regex.Replace(ev.Get("Text"), @"\\(bord|shad|blur)([0-9.]+)", m => "\\" + m.Groups[1].Value + Fmt(Num(m.Groups[2].Value) * effectiveScale));
                    ev.Set("Text", Wrap(text, g, font, Math.Max(1, resX - left - right - outline * 2 - 8), sx, Num(style[sm["Spacing"]]) * effectiveScale, out count));
                    ev.Height = Math.Ceiling(font.GetHeight(g) * sy * count * 1.08 + outline * 2);
                }
                ev.Margin = Num(ev.Get("MarginV"));
                if (ev.Margin == 0) ev.Margin = Num(style[sm["MarginV"]]);
                ev.Gap = Math.Ceiling(Math.Max(8, size * 0.18));
                ev.Set("Style", name); style[sm["Name"]] = name;
                foreach (string key in new[] { "Fontsize", "Outline", "Shadow", "Spacing" }) style[sm[key]] = Fmt(Num(style[sm[key]]) * effectiveScale);
                newStyles.Add("Style: " + string.Join(",", style));
            }
        }
        int pairs = 0;
        foreach (var group in events.Where(e => e.Grouped).GroupBy(e => e.Line))
        {
            var ordered = group.OrderBy(e => e.Part).ToArray();
            if (ordered[0].Align == 2) Array.Reverse(ordered);
            double margin = ordered.Min(e => e.Margin);
            foreach (Event ev in ordered) { ev.Margin = margin; margin += ev.Height + ev.Gap; }
        }
        foreach (Event cn in events.Where(e => e.Lang == 1))
        {
            var jp = events.Where(e => e.Lang == 2 && e.Align == cn.Align && e.Start < cn.End && cn.Start < e.End).ToArray();
            if (jp.Length == 0) continue;
            pairs++;
            if (cn.Grouped) continue;
            if (cn.Align == 2)
                cn.Margin = Math.Max(cn.Margin, jp.Max(e => e.Margin + e.Height + Math.Max(e.Gap, cn.Gap)));
            else
                foreach (Event j in jp) j.Margin = Math.Max(j.Margin, cn.Margin + cn.Height + Math.Max(j.Gap, cn.Gap));
        }
        foreach (Event ev in events)
        {
            if (ev.Margin + ev.Height > resY) throw new InvalidOperationException("Subtitle exceeds canvas vertically at " + ev.Get("Start") + "; reduce scale");
            ev.Set("MarginV", Math.Ceiling(ev.Margin).ToString(Inv));
        }
        foreach (var group in events.GroupBy(e => e.Line))
            lines[group.Key] = string.Join("\n", group.OrderBy(e => e.Part).Select(e => "Dialogue: " + string.Join(",", e.Fields)));
        lines.InsertRange(styleEnd, newStyles);
        // Atomic publication: another player must never read a half-written copy.
        string temporary = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        File.WriteAllLines(temporary, lines, new UTF8Encoding(false));
        try { File.Move(temporary, output); }
        catch (IOException) { if (!File.Exists(output)) throw; File.Delete(temporary); }
        return new[] { events.Count, skipped, pairs, bilingual ? 1 : 0, uncertain };
    }
}
