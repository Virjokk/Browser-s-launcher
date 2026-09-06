namespace HoroscopeWinForms;

public sealed record ZodiacSign(
    string Name,
    string Symbol,
    string Dates,
    int FromMonth,
    int FromDay,
    int ToMonth,
    int ToDay);

public static class Zodiac
{
    public static readonly ZodiacSign[] Signs =
    {
        new("Овен",       "♈", "21 марта — 19 апреля", 3,21,4,19),
        new("Телец",      "♉", "20 апреля — 20 мая",   4,20,5,20),
        new("Близнецы",   "♊", "21 мая — 20 июня",     5,21,6,20),
        new("Рак",        "♋", "21 июня — 22 июля",    6,21,7,22),
        new("Лев",        "♌", "23 июля — 22 августа", 7,23,8,22),
        new("Дева",       "♍", "23 августа — 22 сентября",8,23,9,22),
        new("Весы",       "♎", "23 сентября — 22 октября",9,23,10,22),
        new("Скорпион",   "♏", "23 октября — 21 ноября",10,23,11,21),
        new("Стрелец",    "♐", "22 ноября — 21 декабря",11,22,12,21),
        new("Козерог",    "♑", "22 декабря — 19 января",12,22,1,19),
        new("Водолей",    "♒", "20 января — 18 февраля",1,20,2,18),
        new("Рыбы",       "♓", "19 февраля — 20 марта",2,19,3,20)
    };

    public static ZodiacSign GetSign(DateTime date)
    {
        foreach (var s in Signs)
        {
            if (s.FromMonth == 12)
            {
                if ((date.Month == 12 && date.Day >= s.FromDay) ||
                    (date.Month == 1 && date.Day <= s.ToDay))
                    return s;
            }
            else if ((date.Month == s.FromMonth && date.Day >= s.FromDay) ||
                     (date.Month == s.ToMonth && date.Day <= s.ToDay))
                return s;
        }
        return Signs[0];
    }
}
