# Compilation_Projet
## Compilation — Projet ANTLR (Complexe)

Un petit dépôt pédagogique pour un projet de compilation utilisant des grammaires ANTLR (fichiers fournis : `complexe.g4`, `Complexe__1_.g4`) et un fichier d'exemple `input.txt`.

Ce README décrit rapidement : objectif, prérequis, compilation/génération du parser, exécution d'un exemple, structure du dépôt et prochaines étapes.

### Hypothèses
- Le projet utilise ANTLR4 pour générer un analyseur (parser/lexer).
- Le code cible est en Java (si vous utilisez un autre langage, adaptez la section "Générer et compiler").

Si ces hypothèses sont incorrectes, dites-moi la stack souhaitée (Java, Python, JavaScript, C#, ...). Je peux adapter le README en conséquence.

## Prérequis
- Java 8+ (JDK) installé
- ANTLR4 (jar ou paquet) — installez via votre gestionnaire ou téléchargez `antlr-4.*-complete.jar`
- make, javac et jar (pour l'exemple Java)

## Générer et compiler (exemple Java)
1) Placer `antlr-4.*-complete.jar` dans le dossier racine ou définir sa variable `ANTLR_JAR`.

2) Générer le lexer/parser depuis la grammaire :

```bash
# Exemple (sous zsh/bash) :
export ANTLR_JAR=/chemin/vers/antlr-4.X-complete.jar
java -jar "$ANTLR_JAR" -Dlanguage=Java complexe.g4
```

3) Compiler les sources Java générées et les classes utilitaires :

```bash
javac -cp "$ANTLR_JAR":. *.java
```

4) Exécuter le programme d'exemple (si un Main existe) en fournissant `input.txt` :

```bash
java -cp ".:$ANTLR_JAR" Main input.txt
```

Remarque : adaptez `Main` au nom réel de la classe qui crée l'instance du parser.

## Usage rapide (sans Main)
Vous pouvez aussi invoquer un parseur de test directement depuis une petite classe Java qui lit `input.txt`, crée un CharStream, instancie le lexer puis le parser, et lance la règle principale. Si vous voulez, je peux ajouter ce runner Java minimal.

## Arborescence et rôle des fichiers
- `complexe.g4`, `Complexe__1_.g4` — grammaires ANTLR (lexer + parser)
- `input.txt` — fichier d'exemple pour tester le parser
- `README.md` — ce fichier

---
