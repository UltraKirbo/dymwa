import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class ConnectFourWidget extends StatelessWidget {
  final String chatId;
  final String messageId;
  final Map<String, dynamic> gameData;

  const ConnectFourWidget({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.gameData,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<dynamic> rawBoard = gameData['board'] ?? List.filled(42, 0);
    final List<int> board = rawBoard.cast<int>();
    final String player1 = gameData['player1'] ?? '';
    final String player2 = gameData['player2'] ?? '';
    final String currentTurn = gameData['currentTurn'] ?? '';
    final String winner = gameData['winner'] ?? '';

    bool isMyTurn = (currentTurn == currentUid) && winner.isEmpty;
    bool iAmPlayer1 = (currentUid == player1);
    
    // Déterminer la couleur de mon jeton pour l'affichage
    Color myColor = iAmPlayer1 ? Colors.red : Colors.amber;
    
    String statusText;
    if (winner.isNotEmpty) {
      if (winner == 'draw') {
        statusText = "Match nul !";
      } else if (winner == currentUid) {
        statusText = "Vous avez gagné ! 🏆";
      } else {
        statusText = "Vous avez perdu ! 😥";
      }
    } else {
      statusText = isMyTurn ? "À votre tour de jouer" : "En attente de l'adversaire...";
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gamepad),
                const SizedBox(width: 8),
                Text('Puissance 4', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: winner.isNotEmpty ? Colors.green : Colors.grey)),
            const SizedBox(height: 12),
            // Grille de Puissance 4
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[800], // Le plastique bleu classique du jeu
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, // 7 colonnes
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 42, // 7 colonnes * 6 lignes
                itemBuilder: (context, index) {
                  int cellValue = board[index];
                  Color cellColor = Colors.white;
                  if (cellValue == 1) cellColor = Colors.red;
                  if (cellValue == 2) cellColor = Colors.amber;

                  return GestureDetector(
                    onTap: () {
                      if (isMyTurn) {
                        int col = index % 7;
                        _playMove(col, board, iAmPlayer1, player1, player2);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2)
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playMove(int col, List<int> currentBoard, bool iAmPlayer1, String p1Uid, String p2Uid) {
    // Copier le tableau
    List<int> newBoard = List.from(currentBoard);
    
    // Trouver la ligne la plus basse disponible dans cette colonne
    int targetRow = -1;
    for (int row = 5; row >= 0; row--) {
      int index = row * 7 + col;
      if (newBoard[index] == 0) {
        targetRow = row;
        break;
      }
    }

    if (targetRow == -1) return; // Colonne pleine

    // Placer le jeton (1 pour joueur 1, 2 pour joueur 2)
    int myPiece = iAmPlayer1 ? 1 : 2;
    newBoard[targetRow * 7 + col] = myPiece;

    // Vérifier la victoire
    String winnerUid = _checkWin(newBoard, myPiece) ? (iAmPlayer1 ? p1Uid : p2Uid) : '';
    
    // Vérifier match nul
    if (winnerUid.isEmpty && !newBoard.contains(0)) {
      winnerUid = 'draw';
    }

    // Déterminer le prochain tour
    String nextTurnUid = iAmPlayer1 ? p2Uid : p1Uid;

    ChatService().playConnectFourMove(chatId, messageId, newBoard, nextTurnUid, winnerUid);
  }

  bool _checkWin(List<int> b, int p) {
    // Horizontale
    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 4; c++) {
        if (b[r * 7 + c] == p && b[r * 7 + c + 1] == p && b[r * 7 + c + 2] == p && b[r * 7 + c + 3] == p) return true;
      }
    }
    // Verticale
    for (int c = 0; c < 7; c++) {
      for (int r = 0; r < 3; r++) {
        if (b[r * 7 + c] == p && b[(r + 1) * 7 + c] == p && b[(r + 2) * 7 + c] == p && b[(r + 3) * 7 + c] == p) return true;
      }
    }
    // Diagonale (bas droite)
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        if (b[r * 7 + c] == p && b[(r + 1) * 7 + c + 1] == p && b[(r + 2) * 7 + c + 2] == p && b[(r + 3) * 7 + c + 3] == p) return true;
      }
    }
    // Diagonale (haut droite)
    for (int r = 3; r < 6; r++) {
      for (int c = 0; c < 4; c++) {
        if (b[r * 7 + c] == p && b[(r - 1) * 7 + c + 1] == p && b[(r - 2) * 7 + c + 2] == p && b[(r - 3) * 7 + c + 3] == p) return true;
      }
    }
    return false;
  }
}
