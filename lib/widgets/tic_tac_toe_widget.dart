import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class TicTacToeWidget extends StatelessWidget {
  final String chatId;
  final String messageId;
  final Map<String, dynamic> gameData;

  const TicTacToeWidget({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.gameData,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<dynamic> rawBoard = gameData['board'] ?? List.filled(9, 0);
    final List<int> board = rawBoard.cast<int>();
    final String player1 = gameData['player1'] ?? '';
    final String player2 = gameData['player2'] ?? '';
    final String currentTurn = gameData['currentTurn'] ?? '';
    final String winner = gameData['winner'] ?? '';

    bool isMyTurn = (currentTurn == currentUid) && winner.isEmpty;
    bool iAmPlayer1 = (currentUid == player1);
    
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
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_3x3),
                const SizedBox(width: 8),
                Text('Morpion', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: winner.isNotEmpty ? Colors.green : Colors.grey)),
            const SizedBox(height: 16),
            // Grille Morpion
            Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3x3
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 9,
                itemBuilder: (context, index) {
                  int cellValue = board[index];
                  
                  Widget content = const SizedBox();
                  if (cellValue == 1) {
                    content = const Icon(Icons.close, color: Colors.red, size: 40);
                  } else if (cellValue == 2) {
                    content = const Icon(Icons.circle_outlined, color: Colors.blue, size: 40);
                  }

                  return GestureDetector(
                    onTap: () {
                      if (isMyTurn && cellValue == 0) {
                        _playMove(index, board, iAmPlayer1, player1, player2);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(child: content),
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

  void _playMove(int index, List<int> currentBoard, bool iAmPlayer1, String p1Uid, String p2Uid) {
    List<int> newBoard = List.from(currentBoard);
    
    int myPiece = iAmPlayer1 ? 1 : 2;
    newBoard[index] = myPiece;

    String winnerUid = _checkWin(newBoard, myPiece) ? (iAmPlayer1 ? p1Uid : p2Uid) : '';
    
    if (winnerUid.isEmpty && !newBoard.contains(0)) {
      winnerUid = 'draw';
    }

    String nextTurnUid = iAmPlayer1 ? p2Uid : p1Uid;

    ChatService().playTicTacToeMove(chatId, messageId, newBoard, nextTurnUid, winnerUid);
  }

  bool _checkWin(List<int> b, int p) {
    // Lignes
    if (b[0] == p && b[1] == p && b[2] == p) return true;
    if (b[3] == p && b[4] == p && b[5] == p) return true;
    if (b[6] == p && b[7] == p && b[8] == p) return true;
    // Colonnes
    if (b[0] == p && b[3] == p && b[6] == p) return true;
    if (b[1] == p && b[4] == p && b[7] == p) return true;
    if (b[2] == p && b[5] == p && b[8] == p) return true;
    // Diagonales
    if (b[0] == p && b[4] == p && b[8] == p) return true;
    if (b[2] == p && b[4] == p && b[6] == p) return true;
    return false;
  }
}
