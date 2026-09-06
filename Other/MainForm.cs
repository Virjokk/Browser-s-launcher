using System;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace HoroscopeWinForms;

public sealed class MainForm : Form
{
    private readonly DateTimePicker birthDate = new();
    private readonly DateTimePicker forecastDate = new();
    private readonly ComboBox period = new();
    private readonly Label signLabel = new();
    private readonly Label datesLabel = new();
    private readonly RichTextBox output = new();
    private readonly Button generate = new();
    private ZodiacSign currentSign = Zodiac.Signs[0];

    public MainForm()
    {
        Text = "Гороскоп";
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(820, 650);
        MinimumSize = new Size(700, 560);
        Font = new Font("Segoe UI", 10);
        BackColor = SystemColors.Control;

        var top = new Panel { Dock = DockStyle.Top, Height = 165, Padding = new Padding(14) };
        Controls.Add(top);

        var title = new Label {
            Text = "ГОРОСКОП",
            Font = new Font("Segoe UI", 20, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(16, 10)
        };
        top.Controls.Add(title);

        var b1 = new Label { Text = "Дата рождения:", AutoSize = true, Location = new Point(18, 62) };
        birthDate.Location = new Point(145, 58);
        birthDate.Width = 145;
        birthDate.Format = DateTimePickerFormat.Short;
        birthDate.Value = new DateTime(1990, 1, 1);
        birthDate.ValueChanged += (_, _) => UpdateSign();

        var b2 = new Label { Text = "Прогноз:", AutoSize = true, Location = new Point(315, 62) };
        forecastDate.Location = new Point(385, 58);
        forecastDate.Width = 145;
        forecastDate.Format = DateTimePickerFormat.Short;
        forecastDate.Value = DateTime.Today;

        period.Location = new Point(545, 58);
        period.Width = 120;
        period.DropDownStyle = ComboBoxStyle.DropDownList;
        period.Items.AddRange(new object[] { "Сегодня", "Завтра", "Неделя", "Месяц" });
        period.SelectedIndex = 0;

        signLabel.AutoSize = true;
        signLabel.Font = new Font("Segoe UI", 15, FontStyle.Bold);
        signLabel.Location = new Point(18, 100);

        datesLabel.AutoSize = true;
        datesLabel.Location = new Point(145, 105);

        generate.Text = "Получить прогноз";
        generate.Location = new Point(545, 94);
        generate.Size = new Size(170, 35);
        generate.Click += (_, _) => ShowForecast();

        top.Controls.AddRange(new Control[] { b1, birthDate, b2, forecastDate, period, signLabel, datesLabel, generate });

        output.Dock = DockStyle.Fill;
        output.ReadOnly = true;
        output.BackColor = Color.White;
        output.BorderStyle = BorderStyle.FixedSingle;
        output.Font = new Font("Segoe UI", 11);
        output.Padding = new Padding(14);
        Controls.Add(output);

        UpdateSign();
        ShowForecast();
    }

    private void UpdateSign()
    {
        currentSign = Zodiac.GetSign(birthDate.Value);
        signLabel.Text = $"{currentSign.Symbol} {currentSign.Name}";
        datesLabel.Text = currentSign.Dates;
    }

    private void ShowForecast()
    {
        ForecastPeriod p = period.SelectedIndex switch
        {
            1 => ForecastPeriod.Tomorrow,
            2 => ForecastPeriod.Week,
            3 => ForecastPeriod.Month,
            _ => ForecastPeriod.Today
        };

        var date = forecastDate.Value.Date;
        if (p == ForecastPeriod.Tomorrow) date = date.AddDays(1);

        var f = HoroscopeEngine.Generate(currentSign, date, p);

        var sb = new StringBuilder();
        sb.AppendLine(f["Заголовок"]);
        sb.AppendLine(new string('─', 70));
        sb.AppendLine();
        Append(sb, "ОБЩИЙ ПРОГНОЗ", f["Общий прогноз"]);
        Append(sb, "ЛЮБОВЬ И ОТНОШЕНИЯ", f["Любовь"]);
        Append(sb, "РАБОТА И ДЕЛА", f["Работа"]);
        Append(sb, "ФИНАНСЫ", f["Финансы"]);
        Append(sb, "САМОЧУВСТВИЕ", f["Самочувствие"]);
        Append(sb, "СОВЕТ", f["Совет"]);

        output.Text = sb.ToString();
        output.Select(0, f["Заголовок"].Length);
        output.SelectionFont = new Font(output.Font, FontStyle.Bold);
        output.SelectionStart = 0;
        output.SelectionLength = 0;
    }

    private static void Append(StringBuilder sb, string title, string text)
    {
        sb.AppendLine(title);
        sb.AppendLine(text);
        sb.AppendLine();
    }
}
