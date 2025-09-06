//membre 1: Stephen BOUCHARDON (numero)
//membre 2: Nihal BAZ (numero)
//membre 3: Logan BOIX (22307763)

grammar Complexe;

// ----- Importations Java -----
@parser::header
{
    import java.util.HashMap;
    import java.util.ArrayList;
    import java.io.File;
    import java.io.FileWriter;
    import java.io.BufferedWriter;
    import java.io.IOException;
    import java.lang.Double;
    import java.lang.Math;
    import java.util.Locale;
}

@parser::members
{
    // Tables des variables
    HashMap<String, Integer> varBool = new HashMap<>();
    HashMap<String, Integer> varCom  = new HashMap<>();

    // Compteurs / gestion de la pile
    int adresse    = 0;
    int labelCount = 0;

    // Gestion des break / continue
    ArrayList<String> breakStack    = new ArrayList<>();
    ArrayList<String> continueStack = new ArrayList<>();

    // Genere un nouveau label unique sans prefixe
    String newLabel() {
        String lbl = "L" + labelCount;
        labelCount++;
        return lbl;
    }

    // Remplace la virgule par un point dans une chaine
    String fixDecimalSeparator(String s) {
        return s.replace(',', '.');
    }

    // Formate un double en chaine avec un point comme separateur decimal
    String formatFloat(double d) {
        return String.format(Locale.US, "%.6f", d);
    }
}

// ----- Debut de la Grammaire -----
start
  : calcul EOF
  ;

calcul returns [StringBuilder code]
@init
{
    $code = new StringBuilder();
    // Alloue 20 cellules memoire
    $code.append("ALLOC 20\n");
    adresse += 20;

    // Definir un label de depart principal
    String lblStart = newLabel();
    $code.append("JUMP ").append(lblStart).append("\n");
    $code.append("LABEL ").append(lblStart).append("\n");
}
@after
{
    // Libere les cellules allouees et termine le programme
    $code.append("FREE ").append(adresse).append("\n");
    $code.append("HALT\n");

    try {
        BufferedWriter bw = new BufferedWriter(new FileWriter(new File("a.mvap")));
        bw.write($code.toString());
        bw.close();
    } catch(IOException e) {
        e.printStackTrace();
    }
}
  : (declaration { $code.append($declaration.code); })*
    (instruction { $code.append($instruction.code); })*
  ;

// ----- Declaration de Variables -----
declaration returns [StringBuilder code]
  : tkType=( 'bool' | 'com' ) tkName=IDENT finInstruction
    {
      $code = new StringBuilder();
      String varName = $tkName.text;
      String theType = $tkType.getText();

      if(theType.equals("bool")) {
          // Declaration d'une variable booleenne (1 cellule)
          varBool.put(varName, adresse);
          $code.append("PUSHF 0.0\n");  // false par defaut
          adresse++;
      } else {
          // Declaration d'une variable complexe (2 cellules : reel et imaginaire)
          varCom.put(varName, adresse);
          $code.append("PUSHF 0.0\n"); // partie reelle
          $code.append("PUSHF 0.0\n"); // partie imaginaire
          adresse += 2;
      }
    }
  ;

// ----- Instruction -----
instruction returns [StringBuilder code]
  : assignation finInstruction
    {
      $code = $assignation.code;
    }
  | affichage finInstruction
    {
      $code = $affichage.code;
    }
  | conditionnelle
    {
      $code = $conditionnelle.code;
    }
  | boucle
    {
      $code = $boucle.code;
    }
  | 'break' finInstruction
    {
      $code = new StringBuilder();
      if(!breakStack.isEmpty()) {
         $code.append("JUMP ").append(breakStack.get(breakStack.size()-1)).append("\n");
      }
    }
  | 'continue' finInstruction
    {
      $code = new StringBuilder();
      if(!continueStack.isEmpty()) {
         $code.append("JUMP ").append(continueStack.get(continueStack.size()-1)).append("\n");
      }
    }
  ;

// ----- Assignation : x = expression -----
assignation returns [StringBuilder code]
  : tkName=IDENT '=' expr=expression
    {
      $code = new StringBuilder();
      $code.append($expr.code);

      String varName = $tkName.text;
      if(varBool.containsKey(varName)) {
          // Assignation d'une variable booleenne
          int pos = varBool.get(varName);
          $code.append("STOREG ").append(pos).append("\n");
      } else if (varCom.containsKey(varName)) {
          // Assignation d'une variable complexe
          int base = varCom.get(varName);
          $code.append("STOREG ").append(base).append("\n");     // reel
          $code.append("STOREG ").append(base + 1).append("\n"); // imaginaire
      } else {
          // Variable non declaree
          $code.append("// error: undeclared var ").append(varName).append("\n");
      }
    }
  ;

// ----- Affichage -----
affichage returns [StringBuilder code]
  : 'afficher' '(' c=expressionComplexe ')'
    {
      $code = new StringBuilder();
      String varName = $c.varName;

      if(varCom.containsKey(varName)) {
          int base = varCom.get(varName);

          // Definition des labels necessaires
          String lblCheckReal = newLabel();
          String lblAfterReal = newLabel();
          String lblCheckImag = newLabel();
          String lblPrintPlus = newLabel();
          String lblPrintMinus = newLabel();
          String lblPrintI = newLabel();
          String lblAbsNeg = newLabel();
          String lblAbsPos = newLabel();
          String lblEnd = newLabel();

          // 1. Verifier si real != 0.0
          $code.append("PUSHG ").append(base).append("\n");     // Push real
          $code.append("PUSHF 0.0\n");
          $code.append("FNEQ\n");                              // real !=0.0
          $code.append("JUMPF ").append(lblCheckImag).append("\n"); // Si real ==0.0, sauter A  lblCheckImag

          // 2. Si real !=0.0, afficher real
          $code.append("PUSHG ").append(base).append("\n");     // Push real
          $code.append("WRITEF\n");                            // Affiche real
          $code.append("JUMP ").append(lblAfterReal).append("\n"); // Sauter A  lblAfterReal

          // 3. Label apres affichage du reel
          $code.append("LABEL ").append(lblAfterReal).append("\n");

          // 4. Verifier si imaginaire !=0.0
          $code.append("PUSHG ").append(base + 1).append("\n"); // Push imaginaire
          $code.append("PUSHF 0.0\n");
          $code.append("FNEQ\n");                              // imaginaire !=0.0
          $code.append("JUMPF ").append(lblEnd).append("\n");   // Si imaginaire ==0.0, sauter A  lblEnd

          // 5. Verifier le signe de l'imaginaire
          $code.append("PUSHG ").append(base + 1).append("\n"); // Push imaginaire
          $code.append("PUSHF 0.0\n");
          $code.append("FSUPEQ\n");                            // imaginaire >=0.0
          $code.append("JUMPF ").append(lblPrintMinus).append("\n"); // Si imaginaire <0.0, sauter A  lblPrintMinus
          $code.append("JUMP ").append(lblPrintPlus).append("\n");   // Sinon, sauter A  lblPrintPlus

          // 6. Label pour imaginaire positif ou nul
          $code.append("LABEL ").append(lblPrintPlus).append("\n");
          $code.append("PUSHF 43.0\n"); // '+' (ASCII 43)
          $code.append("WRITEF\n");     // Affiche '+'
          $code.append("JUMP ").append(lblPrintI).append("\n");      // Sauter A  lblPrintI

          // 7. Label pour imaginaire negatif
          $code.append("LABEL ").append(lblPrintMinus).append("\n");
          $code.append("PUSHF 45.0\n"); // '-' (ASCII 45)
          $code.append("WRITEF\n");     // Affiche '-'

          // 8. Label pour afficher 'i'
          $code.append("LABEL ").append(lblPrintI).append("\n");
          $code.append("PUSHF 105.0\n"); // 'i' (ASCII 105)
          $code.append("WRITEF\n");      // Affiche 'i'

          // 9. Afficher la valeur absolue de l'imaginaire
          // Verifier si imaginaire <0.0 pour prendre la valeur absolue
          $code.append("PUSHG ").append(base + 1).append("\n"); // Push imaginaire
          $code.append("DUP\n");                                // Duplique imaginaire
          $code.append("PUSHF 0.0\n");
          $code.append("FSUPEQ\n");                              // imaginaire >=0.0
          $code.append("JUMPF ").append(lblAbsNeg).append("\n"); // Si imaginaire <0.0, sauter A lblAbsNeg
          $code.append("JUMP ").append(lblAbsPos).append("\n");   // Sinon, sauter A  lblAbsPos

          // 10. Label pour imaginaire negatif (afficher -imaginaire)
          $code.append("LABEL ").append(lblAbsNeg).append("\n");
          $code.append("PUSHG ").append(base + 1).append("\n"); // Push imaginaire
          $code.append("FNEG\n");                                // -imaginaire
          $code.append("WRITEF\n");                              // Affiche abs(imaginaire)
          $code.append("JUMP ").append(lblEnd).append("\n");      // Sauter A  lblEnd

          // 11. Label pour imaginaire positif ou nul (afficher imaginaire)
          $code.append("LABEL ").append(lblAbsPos).append("\n");
          $code.append("WRITEF\n");                              // Affiche imaginaire

          // 12. Label de fin de l'affichage
          $code.append("LABEL ").append(lblEnd).append("\n");
      }
     }
      ;
    
// ----- Conditionnelle -----
conditionnelle returns [StringBuilder code]
  : 'lorsque' b=expressionBool 'faire' b1=bloc 'autrement' b2=bloc
    {
      $code = new StringBuilder();
      $code.append($b.code);

      String lblElse = newLabel();
      String lblEnd  = newLabel();

      $code.append("JUMPF ").append(lblElse).append("\n");

      // Bloc si vrai
      $code.append($b1.code);
      $code.append("JUMP ").append(lblEnd).append("\n");

      // Bloc si faux
      $code.append("LABEL ").append(lblElse).append("\n");
      $code.append($b2.code);

      // Fin de la conditionnelle
      $code.append("LABEL ").append(lblEnd).append("\n");
    }
  | 'lorsque' b=expressionBool 'faire' b1=bloc
    {
      $code = new StringBuilder();
      $code.append($b.code);

      String lblEnd = newLabel();
      $code.append("JUMPF ").append(lblEnd).append("\n");

      // Bloc si vrai
      $code.append($b1.code);

      // Fin de la conditionnelle
      $code.append("LABEL ").append(lblEnd).append("\n");
    }
  ;

// ----- Boucle repeter { ... } jusque <expressionBool> sinon { ... } -----
boucle returns [StringBuilder code]
  : 'repeter' b1=bloc 'jusque' bExpr=expressionBool 'sinon' b2=bloc
    {
      $code = new StringBuilder();
      String lblStart = newLabel();
      String lblEnd   = newLabel();
      String lblElse  = newLabel();

      // Empile les labels pour break et continue
      breakStack.add(lblEnd);
      continueStack.add(lblStart);

      // Debut de la boucle
      $code.append("LABEL ").append(lblStart).append("\n");
      $code.append($b1.code);

      // Condition de sortie
      $code.append($bExpr.code);
      $code.append("JUMPF ").append(lblStart).append("\n"); // Si faux, reboucle

      // Si vrai, sauter le bloc 'sinon'
      $code.append("JUMP ").append(lblElse).append("\n");

      // Bloc 'sinon' (break)
      $code.append("LABEL ").append(lblElse).append("\n");
      $code.append($b2.code);

      // Fin de la boucle
      $code.append("LABEL ").append(lblEnd).append("\n");

      // Retire les labels de break et continue
      breakStack.remove(breakStack.size()-1);
      continueStack.remove(continueStack.size()-1);
    }
  ;

// ----- Bloc -----
bloc returns [StringBuilder code]
@init
{
    $code = new StringBuilder();
}
  : '{' (i=instruction { $code.append($i.code); })* '}'
  ;

// ----- Expression (bool ou complexe) -----
expression returns [StringBuilder code]
  : b=expressionBool '?' c1=expressionComplexe ':' c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($b.code);

      String lblElse = newLabel();
      String lblEnd  = newLabel();

      $code.append("JUMPF ").append(lblElse).append("\n");

      // Partie vraie
      $code.append($c1.code);
      $code.append("JUMP ").append(lblEnd).append("\n");

      // Partie fausse
      $code.append("LABEL ").append(lblElse).append("\n");
      $code.append($c2.code);

      // Fin de l'expression conditionnelle
      $code.append("LABEL ").append(lblEnd).append("\n");
    }
  | c=expressionComplexe
    {
      $code = $c.code;
    }
  | b=expressionBool
    {
      $code = new StringBuilder();
      $code.append($b.code);
      // Convertit une expression booleenne en complexe (real = val, imag = 0.0)
      $code.append("PUSHF 0.0\n");
    }
  ;

// ----- Expression Booleenne -----
expressionBool returns [StringBuilder code]
  : '(' inner=expressionBool ')'
    {
      $code = $inner.code;
    }
  | 'non' sub=expressionBool
    {
      $code = new StringBuilder();
      $code.append($sub.code);
      // Negation : (val < 1.0)
      $code.append("PUSHF 1.0\nINF\n");
    }
  | left=expressionBool 'et' right=expressionBool
    {
      $code = new StringBuilder();
      String lblFalse = newLabel();
      String lblFin   = newLabel();

      // evalue left
      $code.append($left.code);
      $code.append("JUMPF ").append(lblFalse).append("\n");

      // evalue right
      $code.append($right.code);
      $code.append("JUMP ").append(lblFin).append("\n");

      // Si left est faux, push 0.0
      $code.append("LABEL ").append(lblFalse).append("\n");
      $code.append("PUSHF 0.0\n");

      // Fin de l'evaluation
      $code.append("LABEL ").append(lblFin).append("\n");
    }
  | left=expressionBool 'ou' right=expressionBool
    {
      $code = new StringBuilder();
      String lblTrue = newLabel();
      String lblFin  = newLabel();

      // evalue left
      $code.append($left.code);
      // Duplique left
      $code.append("DUP\n");
      // Compare avec 0.0
      $code.append("PUSHF 0.0\n");
      $code.append("FEQUAL\n");
      // Si left == 0.0, evalue le right
      $code.append("JUMPF ").append(lblTrue).append("\n");
      $code.append("POP\n");
      $code.append("PUSHF 1.0\n");
      $code.append("JUMP ").append(lblFin).append("\n");

      // Si left est vrai, push 1.0
      $code.append("LABEL ").append(lblTrue).append("\n");
      $code.append("POP\n");
      $code.append("PUSHF 1.0\n");

      // Fin de l'evaluation
      $code.append("LABEL ").append(lblFin).append("\n");
    }
  // Comparaison de deux complexes (comparaison basee sur les modules)
  | c1=expressionComplexe comp=compOp c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c1.code);
      // Stocke real1 et imag1
      $code.append("STOREG 0\n"); // real1
      $code.append("STOREG 1\n"); // imag1

      $code.append($c2.code);
      // Stocke real2 et imag2
      $code.append("STOREG 2\n"); // real2
      $code.append("STOREG 3\n"); // imag2

      // Calcule |c1|^2 = real1^2 + imag1^2
      $code.append("PUSHG 0\n"); // real1
      $code.append("FMUL\n");     // real1 * real1
      $code.append("PUSHG 1\n"); // imag1
      $code.append("FMUL\n");     // imag1 * imag1
      $code.append("FADD\n");     // real1^2 + imag1^2
      $code.append("STOREG 4\n"); // |c1|^2

      // Calcule |c2|^2 = real2^2 + imag2^2
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // real2 * real2
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // imag2 * imag2
      $code.append("FADD\n");     // real2^2 + imag2^2
      $code.append("STOREG 5\n"); // |c2|^2

      // Selon l'operateur de comparaison
      switch($compOp.text) {
        case "==":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("PUSHG 5\n"); // |c2|^2
          $code.append("FEQUAL\n");  // Compare |c1|^2 == |c2|^2
          break;
        case "<>":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("PUSHG 5\n"); // |c2|^2
          $code.append("FNEQ\n");    // Compare |c1|^2 != |c2|^2
          break;
        case "<":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("PUSHG 5\n"); // |c2|^2
          $code.append("FINF\n");    // Compare |c1|^2 < |c2|^2
          break;
        case ">":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("FSUP\n");    // Compare |c1|^2 > |c2|^2
          break;
        case "<=":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("FINFEQ\n");  // Compare |c1|^2 <= |c2|^2
          break;
        case ">=":
          $code.append("PUSHG 4\n"); // |c1|^2
          $code.append("FSUPEQ\n");  // Compare |c1|^2 >= |c2|^2
          break;
      }
    }
  | tkBool=BOOL
    {
      $code = new StringBuilder();
      if($tkBool.text.equals("true")) {
        $code.append("PUSHF 1.0\n");
      } else {
        $code.append("PUSHF 0.0\n");
      }
    }
  | tkId=IDENT
    {
      $code = new StringBuilder();
      String v = $tkId.text;
      if(varBool.containsKey(v)) {
         $code.append("PUSHG ").append(varBool.get(v)).append("\n");
      } else {
         $code.append("// error: ").append(v).append(" is not bool\n");
         $code.append("PUSHF 0.0\n");
      }
    }
  ;

// ----- Operateurs de Comparaison -----
compOp 
  : '==' 
  | '<>' 
  | '<' 
  | '>' 
  | '<=' 
  | '>=' 
  ;

// ----- Expression Complexe -----
expressionComplexe returns [StringBuilder code, String varName]
  : IDENT
    {
      $code = new StringBuilder();
      String v = $IDENT.text;
      if(varCom.containsKey(v)) {
         int base = varCom.get(v);
         // Empile reel et imaginaire depuis la memoire
         $code.append("PUSHG ").append(base).append("\n");     // reel
         $code.append("PUSHG ").append(base + 1).append("\n"); // imaginaire
         $varName = v;
      } else {
         // Variable non declaree comme complexe
         $code.append("PUSHF 0.0\nPUSHF 0.0\n");
         $varName = null;
      }
    }
  | 'i' f=FLOAT
    {
      $code = new StringBuilder();
      // Parse la partie imaginaire
      double val=0.0;
      try {
         val = Double.parseDouble(fixDecimalSeparator($f.text));
      } catch(Exception e){ }

      // Empile reel = 0.0 et imaginaire = val
      $code.append("PUSHF 0.0\n");
      $code.append("PUSHF ").append(formatFloat(val)).append("\n");
      $varName = null;
    }
  | f=FLOAT
    {
      $code = new StringBuilder();
      double val=0.0;
      try {
         val = Double.parseDouble(fixDecimalSeparator($f.text));
      } catch(Exception e){ }

      // Empile reel = val et imaginaire = 0.0
      $code.append("PUSHF ").append(formatFloat(val)).append("\n");
      $code.append("PUSHF 0.0\n");
      $varName = null;
    }
  | '(' c=expressionComplexe ')'
    {
      $code = $c.code;
      $varName = $c.varName;
    }
  | '-' c=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c.code);
      // Negation des parties reelles et imaginaires
      $code.append("FNEG\n");    // Negation de l'imaginaire
      $code.append("FNEG\n");    // Negation du reel

      // Reempile les parties negatives
      $code.append("PUSHG 0\n"); // -reel
      $code.append("PUSHG 1\n"); // -imaginaire

      $varName = $c.varName;
    }
  | 'lire' '(' ')'
    {
      $code = new StringBuilder();
      // Lit la partie reelle
      $code.append("READF\n");
      $code.append("STOREG 0\n"); // reel

      // Lit la partie imaginaire
      $code.append("READF\n");
      $code.append("STOREG 1\n"); // imaginaire

      // Reempile les parties reelles et imaginaires
      $code.append("PUSHG 0\n");
      $code.append("PUSHG 1\n");

      $varName = null;
    }
  | c1=expressionComplexe '+' c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c1.code);  // [real1, imag1]
      $code.append($c2.code);  // [real2, imag2]
      $code.append("STOREG 3\n"); // imag2
      $code.append("STOREG 2\n"); // real2
      $code.append("STOREG 5\n"); // imag1
      $code.append("STOREG 4\n"); // real1

      // newReal = real1 + real2
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FADD\n");    // real1 + real2
      $code.append("STOREG 6\n"); // stocke newReal

      // newImag = imag1 + imag2
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FADD\n");    // imag1 + imag2
      $code.append("STOREG 7\n"); // stocke newImag

      // Empile les nouvelles parties
      $code.append("PUSHG 6\n"); // newReal
      $code.append("PUSHG 7\n"); // newImag

      $varName = null;
    }
  | c1=expressionComplexe '-' c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c1.code);
      $code.append($c2.code);
      $code.append("STOREG 3\n"); // imag2
      $code.append("STOREG 2\n"); // real2
      $code.append("STOREG 5\n"); // imag1
      $code.append("STOREG 4\n"); // real1

      // newReal = real1 - real2
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FSUB\n");    // real1 - real2
      $code.append("STOREG 6\n"); // stocke newReal

      // newImag = imag1 - imag2
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FSUB\n");    // imag1 - imag2
      $code.append("STOREG 7\n"); // stocke newImag

      // Empile les nouvelles parties
      $code.append("PUSHG 6\n"); // newReal
      $code.append("PUSHG 7\n"); // newImag

      $varName = null;
    }
  | c1=expressionComplexe '*' c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c1.code);
      $code.append($c2.code);
      $code.append("STOREG 3\n"); // imag2
      $code.append("STOREG 2\n"); // real2
      $code.append("STOREG 5\n"); // imag1
      $code.append("STOREG 4\n"); // real1

      // newReal = real1 * real2 - imag1 * imag2
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // real1 * real2
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // imag1 * imag2
      $code.append("FSUB\n");     // real1 * real2 - imag1 * imag2
      $code.append("STOREG 6\n"); // stocke newReal

      // newImag = real1 * imag2 + imag1 * real2
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // real1 * imag2
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // imag1 * real2
      $code.append("FADD\n");     // real1 * imag2 + imag1 * real2
      $code.append("STOREG 7\n"); // stocke newImag

      // Empile les nouvelles parties
      $code.append("PUSHG 6\n"); // newReal
      $code.append("PUSHG 7\n"); // newImag

      $varName = null;
    }
  | c1=expressionComplexe '/' c2=expressionComplexe
    {
      $code = new StringBuilder();
      $code.append($c1.code);
      $code.append($c2.code);
      $code.append("STOREG 3\n"); // imag2
      $code.append("STOREG 2\n"); // real2
      $code.append("STOREG 5\n"); // imag1
      $code.append("STOREG 4\n"); // real1

      // denom = real2^2 + imag2^2
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // real2 * real2
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // imag2 * imag2
      $code.append("FADD\n");     // real2^2 + imag2^2
      $code.append("STOREG 8\n"); // denom

      // real = (real1 * real2 + imag1 * imag2) / denom
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // real1 * real2
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // imag1 * imag2
      $code.append("FADD\n");     // real1 * real2 + imag1 * imag2
      $code.append("PUSHG 8\n"); // denom
      $code.append("FDIV\n");     // / denom
      $code.append("STOREG 6\n"); // real

      // imag = (imag1 * real2 - real1 * imag2) / denom
      $code.append("PUSHG 5\n"); // imag1
      $code.append("PUSHG 2\n"); // real2
      $code.append("FMUL\n");     // imag1 * real2
      $code.append("PUSHG 4\n"); // real1
      $code.append("PUSHG 3\n"); // imag2
      $code.append("FMUL\n");     // real1 * imag2
      $code.append("FSUB\n");     // imag1 * real2 - real1 * imag2
      $code.append("PUSHG 8\n"); // denom
      $code.append("FDIV\n");     // / denom
      $code.append("STOREG 7\n"); // imag

      // Empile les nouvelles parties
      $code.append("PUSHG 6\n"); // real
      $code.append("PUSHG 7\n"); // imag

      $varName = null;
    }
  // Exponentiation complexe (c**N)
  | base=expressionComplexe EXPONENT sign=SIGN? exp=INT
    {
      $code = new StringBuilder();
      $code.append($base.code);
      // Stocke base : reel (0), imaginaire (1)
      $code.append("STOREG 0\n"); // reel
      $code.append("STOREG 1\n"); // imaginaire

      // Initialise res = 1.0 + i0.0
      $code.append("PUSHF 1.0\n"); // res_real = 1.0
      $code.append("PUSHF 0.0\n"); // res_imag = 0.0
      $code.append("STOREG 3\n");   // res_real
      $code.append("STOREG 2\n");   // res_imag

      // Recupere le texte de l'exposant avec le signe
      String exponentText = ($sign != null ? $sign.text : "") + $exp.text;
      int n = Integer.parseInt(fixDecimalSeparator(exponentText));

      for(int i=0; i<Math.abs(n); i++){
        // res = res * base
        // res_real = res_real * base_real - res_imag * base_imag
        $code.append("PUSHG 3\n"); // res_real
        $code.append("PUSHG 0\n"); // base_real
        $code.append("FMUL\n");     // res_real * base_real
        $code.append("PUSHG 2\n"); // res_imag
        $code.append("PUSHG 1\n"); // base_imag
        $code.append("FMUL\n");     // res_imag * base_imag
        $code.append("FSUB\n");     // res_real * base_real - res_imag * base_imag
        $code.append("STOREG 6\n"); // temp_real

        // res_imag = res_real * base_imag + res_imag * base_real
        $code.append("PUSHG 3\n"); // res_real
        $code.append("PUSHG 1\n"); // base_imag
        $code.append("FMUL\n");     // res_real * base_imag
        $code.append("PUSHG 2\n"); // res_imag
        $code.append("PUSHG 0\n"); // base_real
        $code.append("FMUL\n");     // res_imag * base_real
        $code.append("FADD\n");     // res_real * base_imag + res_imag * base_real
        $code.append("STOREG 7\n"); // temp_imag

        // Met Ã  jour res
        $code.append("PUSHG 6\n"); // temp_real
        $code.append("STOREG 3\n"); // res_real
        $code.append("PUSHG 7\n"); // temp_imag
        $code.append("STOREG 2\n"); // res_imag
      }

      // Empile res_real et res_imag
      $code.append("PUSHG 3\n"); // res_real
      $code.append("PUSHG 2\n"); // res_imag

      if(n < 0) {
         $code.append("// negative exponent not fully managed\n");
      }

      $varName = null;
    }
  // Fonction reel(c)
  | 'reel' '(' c=expressionComplexe ')'
    {
      $code = new StringBuilder();
      $code.append($c.code);
      // Stocke imag et reel
      $code.append("STOREG 1\n"); // imag
      $code.append("STOREG 0\n"); // real

      // Empile reel et 0.0 pour imaginaire
      $code.append("PUSHG 0\n");   // reel
      $code.append("PUSHF 0.0\n"); // imaginaire

      $varName = null;
    }
  // Fonction im(c)
  | 'im' '(' c=expressionComplexe ')'
    {
      $code = new StringBuilder();
      $code.append($c.code);
      // Stocke imag et reel
      $code.append("STOREG 1\n"); // imag
      $code.append("STOREG 0\n"); // real

      // Empile 0.0 pour reel et imaginaire
      $code.append("PUSHF 0.0\n"); // reel
      $code.append("PUSHG 1\n");    // imaginaire

      $varName = null;
    }
  // Notation polaire r:th
  | r=FLOAT ':' th=FLOAT
    {
      $code = new StringBuilder();
      double rr = 0.0, tt = 0.0;
      try {
          rr = Double.parseDouble(fixDecimalSeparator($r.text));
          tt = Double.parseDouble(fixDecimalSeparator($th.text));
      } catch(Exception e){ }

      double rad = Math.toRadians(tt);
      double real = rr * Math.cos(rad);
      double imag = rr * Math.sin(rad);

      $code.append("PUSHF ").append(formatFloat(real)).append("\n");
      $code.append("PUSHF ").append(formatFloat(imag)).append("\n");

      $varName = null;
    }
  // Notation polaire r e^i th
  | r=FLOAT 'e^i' th=FLOAT
    {
      $code = new StringBuilder();
      double rr = 0.0, tt = 0.0;
      try {
          rr = Double.parseDouble(fixDecimalSeparator($r.text));
          tt = Double.parseDouble(fixDecimalSeparator($th.text));
      } catch(Exception e){ }

      double rad = Math.toRadians(tt);
      double real = rr * Math.cos(rad);
      double imag = rr * Math.sin(rad);

      $code.append("PUSHF ").append(formatFloat(real)).append("\n");
      $code.append("PUSHF ").append(formatFloat(imag)).append("\n");

      $varName = null;
    }
  // Constante imaginaire i f
  | 'i' f=FLOAT
    {
      $code = new StringBuilder();

      // Parse la partie imaginaire
      double val=0.0;
      try {
         val = Double.parseDouble(fixDecimalSeparator($f.text));
      } catch(Exception e){ }

      // Empile reel = 0.0 et imaginaire = val
      $code.append("PUSHF 0.0\n");
      $code.append("PUSHF ").append(formatFloat(val)).append("\n");

      $varName = null;
    }
  | f=FLOAT
    {
      $code = new StringBuilder();
      double val=0.0;
      try {
         val = Double.parseDouble(fixDecimalSeparator($f.text));
      } catch(Exception e){ }

      // Empile reel = val et imaginaire = 0.0
      $code.append("PUSHF ").append(formatFloat(val)).append("\n");
      $code.append("PUSHF 0.0\n");

      $varName = null;
    }
  | tkId=IDENT
    {
      $code = new StringBuilder();
      String v = $tkId.text;
      if(varCom.containsKey(v)) {
         int base = varCom.get(v);
         // Empile reel et imaginaire depuis la memoire
         $code.append("PUSHG ").append(base).append("\n");     // reel
         $code.append("PUSHG ").append(base + 1).append("\n"); // imaginaire
         $varName = v;
      } else {
         // Variable non declaree comme complexe
         $code.append("PUSHF 0.0\nPUSHF 0.0\n");
         $varName = null;
      }
    }
  // Constante imaginaire IMAGCST (i2, i-3.14, etc.)
  | icst=IMAGCST
    {
      $code = new StringBuilder();
      // Ex : "i2", "i-3.14", "i+5"
      String txt = $icst.text.substring(1); // retire le 'i'
      txt = fixDecimalSeparator(txt);
      double val=0.0;
      try {
         val = Double.parseDouble(txt);
      } catch(Exception e){ }

      // Empile reel = 0.0 et imaginaire = val
      $code.append("PUSHF 0.0\n");
      $code.append("PUSHF ").append(formatFloat(val)).append("\n");

      $varName = null;
    }
  ;

// ----- Fin d'Instruction -----
finInstruction : ';' ;

// ----- Tokens -----
fragment DIGIT : [0-9] ;

SIGN : [+\-] ;

INT : DIGIT+ ;

EXPONENT : '**' ;

FLOAT 
  : [+\-]? DIGIT+ ('.' DIGIT+)?     // ex : +12.34, -5.0, 10.25
  | [+\-]? '.' DIGIT+               // ex : .25, -.5, +.75
  ;

IMAGCST : 'i' [+\-]? DIGIT+ ('.' DIGIT+)? ; // i2, i-3.14, i+5

IDENT : [a-zA-Z_] [a-zA-Z0-9_]* ; // identifiants

BOOL : 'true' | 'false' ; // booleens

// Ignorer les commentaires et les espaces
COMMENT : '//' ~[\r\n]* -> skip ;
WS : [ \t\r\n]+ -> skip ;
UNMATCH : . -> skip ;
