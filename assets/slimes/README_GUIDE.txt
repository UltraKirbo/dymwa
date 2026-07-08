=== GUIDE DES SPRITES POUR LE SLIME RPG ===

Pour gérer toutes les animations (marche, repos, saut), chaque accessoire, bouche, œil, et base doit posséder une image par "état" (state).

Les états prévus sont :
1. idle (Au repos)
2. walk (Marche)
3. jump (Saut)

--- NOMENCLATURE ---
Format : [type]_[nom]_[etat].png

Exemples pour la Base "Rouge" :
- bases/base_red_idle.png
- bases/base_red_walk.png
- bases/base_red_jump.png

Exemples pour les Yeux "Mignons" :
- eyes/eyes_cute_idle.png
- eyes/eyes_cute_walk.png
- eyes/eyes_cute_jump.png

--- DIMENSIONS ET ALIGNEMENT ---
Toutes les images d'un même état (ex: tous les _walk.png) DOIVENT avoir exactement la même grille (ex: 4 colonnes, 4 lignes) et la même taille en pixels.
Cela permet de superposer la couronne parfaite sur la tête du Slime, peu importe l'animation !

Vous pouvez supprimer les vieux fichiers d'exemples (.txt) et commencer à glisser vos vrais .png ici.
