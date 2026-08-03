import 'subject_model.dart';

class SubjectAI {
  static final Map<String, List<String>> keywords = {

    "Matematik": [
      "üçgen",
      "fonksiyon",
      "türev",
      "integral",
      "limit",
      "denklem",
      "polinom",
      "eşitsizlik",
      "logaritma",
      "trigonometri",
      "sin",
      "cos",
      "tan",
      "geometri",
    ],

    "Fizik": [
      "vektör",
      "kuvvet",
      "hız",
      "ivme",
      "enerji",
      "hareket",
      "elektrik",
      "manyetik",
      "dalga",
      "optik",
      "momentum",
    ],

    "Kimya": [
      "atom",
      "molekül",
      "mol",
      "asit",
      "baz",
      "iyon",
      "reaksiyon",
      "bağ",
      "periyodik",
      "kimyasal",
    ],

    "Biyoloji": [
      "canlı",
      "yaşam",
      "hücre",
      "dna",
      "gen",
      "kalıtım",
      "fotosentez",
      "ekosistem",
      "organ",
      "mitoz",
      "mayoz",
    ],

    "Türkçe": [
      "paragraf",
      "fiil",
      "isim",
      "sıfat",
      "zarf",
      "edat",
      "anlam",
    ],

    "Tarih": [
      "osmanlı",
      "savaş",
      "devlet",
      "inkılap",
      "atatürk",
      "antlaşma",
    ],

  };


  static String? predict(String text) {

    text = text.toLowerCase();

    Map<String,int> scores = {};

    for (var subject in keywords.keys) {
      scores[subject] = 0;

      for (var word in keywords[subject]!) {
        if (text.contains(word)) {
          scores[subject] = scores[subject]! + 1;
        }
      }
    }


    String? result;
    int maxScore = 0;


    scores.forEach((subject, score) {

      if(score > maxScore){
        maxScore = score;
        result = subject;
      }

    });


    return maxScore > 0 ? result : null;
  }
}