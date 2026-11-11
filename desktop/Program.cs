using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WinFix.Health
{
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (args.Length == 3 && args[0] == "--test-collect")
            {
                try { return Collector.Run(args[1], args[2], CancellationToken.None).Partial ? 2 : 0; }
                catch (Exception) { return 1; }
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (var form = new MainWindow())
            {
                if (args.Length == 1 && args[0] == "--test-window")
                {
                    form.Shown += delegate { form.BeginInvoke(new Action(form.Close)); };
                }
                Application.Run(form);
            }
            return 0;
        }
    }

    internal sealed class Report
    {
        internal readonly string Directory;
        internal readonly bool Partial;
        internal Report(string directory, bool partial) { Directory = directory; Partial = partial; }
    }

    internal static class Collector
    {
        internal static Report Run(string destination, string language, CancellationToken cancellation)
        {
            string work = Path.Combine(Path.GetTempPath(), "WinFixHealth-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            try
            {
                string script = Path.Combine(work, "Collect.ps1");
                string result = Path.Combine(work, "result.txt");
                Extract("Collect.ps1", script);
                Extract("WinFix.Health.psm1", Path.Combine(work, "WinFix.Health.psm1"));
                string engine = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
                var start = new ProcessStartInfo(engine,
                    "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + Quote(script)
                    + " -OutputDirectory " + Quote(destination) + " -ResultFile " + Quote(result)
                    + " -Language " + (language == "fr" ? "fr" : "en"));
                start.WorkingDirectory = work;
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardError = true;
                cancellation.ThrowIfCancellationRequested();
                using (Process process = Process.Start(start))
                {
                    var errors = process.StandardError.ReadToEndAsync();
                    var elapsed = Stopwatch.StartNew();
                    try
                    {
                        while (!process.WaitForExit(200))
                        {
                            cancellation.ThrowIfCancellationRequested();
                            if (elapsed.Elapsed > TimeSpan.FromMinutes(5)) throw new TimeoutException();
                        }
                        cancellation.ThrowIfCancellationRequested();
                        if (process.ExitCode != 0 && process.ExitCode != 2)
                            throw new IOException(errors.GetAwaiter().GetResult());
                        string path = Path.GetFullPath(File.ReadAllText(result));
                        string parent = Path.GetFullPath(destination).TrimEnd(Path.DirectorySeparatorChar);
                        if (!String.Equals(Path.GetDirectoryName(path).TrimEnd(Path.DirectorySeparatorChar), parent, StringComparison.OrdinalIgnoreCase)
                            || !File.Exists(Path.Combine(path, "report.html")) || !File.Exists(Path.Combine(path, "report.json")))
                            throw new IOException("The report is incomplete.");
                        return new Report(path, process.ExitCode == 2);
                    }
                    finally
                    {
                        if (!process.HasExited)
                        {
                            try { process.Kill(); }
                            catch (InvalidOperationException) { }
                            process.WaitForExit();
                        }
                    }
                }
            }
            finally
            {
                try { Directory.Delete(work, true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        private static string Quote(string path)
        {
            return "\"" + path + new string('\\', path.Length - path.TrimEnd('\\').Length) + "\"";
        }

        private static void Extract(string resource, string path)
        {
            using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(resource))
            using (Stream target = new FileStream(path, FileMode.CreateNew, FileAccess.Write))
                source.CopyTo(target);
        }
    }

    internal sealed class MainWindow : Form
    {
        private readonly Label title = new Label();
        private readonly Label explanation = new Label();
        private readonly Label destinationLabel = new Label();
        private readonly Label status = new Label();
        private readonly TextBox destination = new TextBox();
        private readonly ComboBox language = new ComboBox();
        private readonly Button choose = new Button();
        private readonly Button collect = new Button();
        private readonly Button cancel = new Button();
        private readonly Button open = new Button();
        private readonly Button folder = new Button();
        private readonly Button license = new Button();
        private readonly ProgressBar progress = new ProgressBar();
        private CancellationTokenSource active;
        private Report report;
        private bool closing;
        private bool French { get { return language.SelectedIndex == 0; } }
        private string T(string fr, string en) { return French ? fr : en; }

        internal MainWindow()
        {
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(660, 425);
            MinimumSize = new Size(610, 445);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 10F);
            BackColor = Color.White;
            ForeColor = Color.FromArgb(23, 43, 64);

            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(22), ColumnCount = 1, AutoScroll = true };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            Controls.Add(layout);
            language.DropDownStyle = ComboBoxStyle.DropDownList;
            language.Items.AddRange(new object[] { "Français", "English" });
            language.AccessibleName = "Langue / Language";
            language.Width = 115;
            layout.Controls.Add(Row(language, license));
            title.Font = new Font("Segoe UI Semibold", 19F);
            AddLabel(layout, title);
            AddLabel(layout, explanation);
            AddLabel(layout, destinationLabel);
            var destinationRow = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 2 };
            destinationRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            destinationRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            destination.ReadOnly = true;
            destination.Dock = DockStyle.Fill;
            string documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            destination.Text = Path.Combine(String.IsNullOrEmpty(documents) ? Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) : documents, "WinFix-Reports");
            destinationRow.Controls.Add(destination, 0, 0);
            destinationRow.Controls.Add(choose, 1, 0);
            layout.Controls.Add(destinationRow);
            layout.Controls.Add(Row(collect, cancel));
            progress.Dock = DockStyle.Top;
            progress.Height = 6;
            progress.Style = ProgressBarStyle.Marquee;
            progress.Visible = false;
            layout.Controls.Add(progress);
            AddLabel(layout, status);
            layout.Controls.Add(Row(open, folder));
            foreach (Button button in new[] { collect, choose, open, folder, cancel, license })
                button.AutoSize = true;
            collect.Padding = new Padding(12, 5, 12, 5);
            collect.FlatStyle = FlatStyle.Flat;
            collect.BackColor = Color.FromArgb(19, 89, 108);
            collect.ForeColor = Color.White;
            AcceptButton = collect;

            language.SelectedIndexChanged += delegate { Translate(); };
            choose.Click += delegate
            {
                using (var dialog = new FolderBrowserDialog())
                {
                    dialog.Description = T("Choisissez où enregistrer les rapports.", "Choose where to save the reports.");
                    if (Directory.Exists(destination.Text)) dialog.SelectedPath = destination.Text;
                    if (dialog.ShowDialog(this) == DialogResult.OK) destination.Text = dialog.SelectedPath;
                }
            };
            collect.Click += Collect;
            cancel.Click += delegate { if (active != null) active.Cancel(); };
            open.Click += delegate { if (report != null) Open(Path.Combine(report.Directory, "report.html")); };
            folder.Click += delegate { if (report != null) Open(report.Directory); };
            license.Click += delegate
            {
                using (var text = new StreamReader(Assembly.GetExecutingAssembly().GetManifestResourceStream("LICENSE")))
                    MessageBox.Show(this, text.ReadToEnd(), "MIT", MessageBoxButtons.OK, MessageBoxIcon.Information);
            };
            FormClosing += delegate(object sender, FormClosingEventArgs e)
            {
                if (active == null) return;
                e.Cancel = true;
                closing = true;
                active.Cancel();
            };
            language.SelectedIndex = Thread.CurrentThread.CurrentUICulture.TwoLetterISOLanguageName == "fr" ? 0 : 1;
            SetBusy(false);
        }

        private static FlowLayoutPanel Row(params Control[] controls)
        {
            var row = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = true };
            row.Controls.AddRange(controls);
            return row;
        }

        private static void AddLabel(TableLayoutPanel layout, Label label)
        {
            label.AutoSize = true;
            label.Dock = DockStyle.Top;
            label.Margin = new Padding(3, 7, 3, 7);
            layout.Controls.Add(label);
        }

        private void Translate()
        {
            Text = title.Text = T("Rapport de santé du système", "System Health Report");
            explanation.Text = T("Analysez Windows, le matériel et les événements récents. Les rapports restent sur votre ordinateur.",
                "Review Windows, hardware and recent events. Reports stay on your computer.");
            destination.AccessibleName = destinationLabel.Text = T("Dossier des rapports", "Reports folder");
            choose.Text = T("Choisir…", "Choose…");
            collect.Text = T("Créer le rapport", "Create report");
            cancel.Text = T("Annuler", "Cancel");
            open.Text = T("Ouvrir le rapport", "Open report");
            folder.Text = T("Ouvrir le dossier", "Open folder");
            license.Text = T("Licence MIT", "MIT license");
            ShowResult();
        }

        private void ShowResult()
        {
            if (report == null) status.Text = T("Prêt à analyser en lecture seule.", "Ready for a read-only scan.");
            else if (report.Partial) status.Text = T("Rapport créé. Certaines sources sont indisponibles.", "Report created. Some sources are unavailable.");
            else status.Text = T("Rapport HTML et fichier JSON créés.", "HTML report and JSON file created.");
        }

        private async void Collect(object sender, EventArgs e)
        {
            string path = destination.Text;
            string selectedLanguage = French ? "fr" : "en";
            active = new CancellationTokenSource();
            var token = active.Token;
            report = null;
            SetBusy(true);
            status.Text = T("Collecte des informations en cours…", "Collecting system information…");
            try
            {
                report = await Task.Run(() => Collector.Run(path, selectedLanguage, token));
                ShowResult();
            }
            catch (OperationCanceledException) { status.Text = T("Analyse annulée.", "Scan canceled."); }
            catch (Exception failure)
            {
                status.Text = T("Le rapport n’a pas pu être créé.", "The report could not be created.");
                MessageBox.Show(this, T("Vérifiez que le dossier est accessible, puis réessayez.", "Check that the folder is writable, then try again.")
                    + Environment.NewLine + failure.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                active.Dispose();
                active = null;
                SetBusy(false);
                if (closing) Close();
            }
        }

        private void SetBusy(bool busy)
        {
            collect.Enabled = choose.Enabled = language.Enabled = !busy;
            open.Enabled = folder.Enabled = !busy && report != null;
            cancel.Visible = progress.Visible = busy;
        }

        private void Open(string path)
        {
            try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
            catch (Exception)
            {
                MessageBox.Show(this, path, T("Ouverture impossible", "Could not open"), MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
    }
}
