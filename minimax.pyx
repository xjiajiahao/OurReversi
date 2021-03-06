import sys
import ai

max_depth = 5

class MiniMax(ai.AI):
    def __init__(self, board, **kwargs):
        super(MiniMax, self).__init__(board, **kwargs)
        self.eval_engine = Eval(self.board)

    def get_action(self):
        state = self.history[-1]
        player = self.board.current_player(state)
        # goal: player 1: max, player 2: min
        best_action = None
        if player == 1:
            value, best_action = self.Max(state, max_depth, float('-inf'), float('inf'), player)
        else:
            value, best_action = self.Min(state, max_depth, float('-inf'), float('inf'), player)
        print 'evaluation : ', value
        return self.board.unpack_action(best_action)

    def Max(self, state, depth, alpha, beta, player):
        if depth == 0:
            #return self.board.not_ended_points_values([state])[1], None  # return [point, action]
            return self.EvaluateState(state), None

        legal = self.board.legal_actions([state])
        if not legal:
            if self.board.is_ended([state]):
                #best = self.board.not_ended_points_values([state])[1]
                best = self.EvaluateState(state)
                #print 'max: time to return', 'best: ', best, 'alpha: ', alpha, 'beta: ', beta# @DEBUG
                return best, None
            return self.Min(state, depth, alpha, beta, 3 - player)
        best = float('-inf')
        best_action = None

        for oneAction in legal:
            alpha = max(best, alpha)
            if alpha >= beta:
                break
            new_state = self.board.next_state(state, oneAction)
            value, min_action = self.Min(new_state, depth - 1, max(best, alpha), beta, 3 - player)
            if value > best:
                best = value
                best_action = oneAction
        return best, best_action

    def Min(self, state, depth, alpha, beta, player):
        if depth == 0:
            #return self.board.not_ended_points_values([state])[1], None  # return [point, action]
            return self.EvaluateState(state), None

        legal = self.board.legal_actions([state])
        if not legal:
            if self.board.is_ended([state]):
                #best = self.board.not_ended_points_values([state])[1]
                best = self.EvaluateState(state)
                #print 'min: time to return', 'best: ', best, 'alpha: ', alpha, 'beta: ', beta# @DEBUG
                return best, None
            return self.Max(state, depth, alpha, beta, 3 - player)

        best = float('inf')
        best_action = None

        for oneAction in legal:
            beta = min(best, beta)
            if alpha >= beta:
                break
            new_state = self.board.next_state(state, oneAction)
            value, max_action = self.Max(new_state, depth - 1, alpha, min(beta, best), 3 - player)
            if value < best:
                best = value
                best_action = oneAction
        return best, best_action

    def EvaluateState(self, state):
        w, b = self.eval_engine.to_bitboard(state)
        #print 'debug:', player, self.eval_engine.eval(w, b), self.eval_engine.eval(b, w)
        #if player == 1:
        res = self.eval_engine.eval(w, b)
        #elif player == 2:
        #    res = self.eval_engine.eval(b, w)
        return res

# @NOTE Acknowledgement: the evaluation function is written by the TA of another AI class, which is awesome
cdef class Eval(object):
    cdef int WEIGHTS[7]
    cdef unsigned long P_RINGS[7]
    cdef unsigned long P_CORNER
    cdef unsigned long P_SUB_CORNER
    cdef unsigned long FULL_MASK
    cdef unsigned long BIT[64]
    cdef object board

    def __init__(self, board, **kwargs):
        self.board = board

        self.WEIGHTS[7]
        self.WEIGHTS[:] = [-3, -7, 11, -4, 8, 1, 2]
        self.P_RINGS[:] = [0x4281001818008142,
                   0x42000000004200,
                   0x2400810000810024,
                   0x24420000422400,
                   0x1800008181000018,
                   0x18004242001800,
                   0x3C24243C0000]
        self.P_CORNER = 0x8100000000000081
        self.P_SUB_CORNER = 0x42C300000000C342
        self.FULL_MASK = 0xFFFFFFFFFFFFFFFF
        self.BIT[:] = [1 << n for n in range(64)]

    cpdef eval(self, W, B):
        cdef unsigned long w0 = W & self.BIT[0] != 0
        cdef unsigned long w1 = W & self.BIT[7] != 0
        cdef unsigned long w2 = W & self.BIT[56] != 0
        cdef unsigned long w3 = W & self.BIT[63] != 0
        cdef unsigned long b0 = B & self.BIT[0] != 0
        cdef unsigned long b1 = B & self.BIT[7] != 0
        cdef unsigned long b2 = B & self.BIT[56] != 0
        cdef unsigned long b3 = B & self.BIT[63] != 0

        # stability
        cdef int wunstable = 0
        cdef int bunstable = 0
        if w0 != 1 and b0 != 1:
            wunstable += (W & self.BIT[1] != 0) + (W & self.BIT[8] != 0) + (W & self.BIT[9] != 0)
            bunstable += (B & self.BIT[1] != 0) + (B & self.BIT[8] != 0) + (B & self.BIT[9] != 0)
        if w1 != 1 and b1 != 1:
            wunstable += (W & self.BIT[6] != 0) + (W & self.BIT[14] != 0) + (W & self.BIT[15] != 0)
            bunstable += (B & self.BIT[6] != 0) + (B & self.BIT[14] != 0) + (B & self.BIT[15] != 0)
        if w2 != 1 and b2 != 1:
            wunstable += (W & self.BIT[48] != 0) + (W & self.BIT[49] != 0) + (W & self.BIT[57] != 0)
            bunstable += (B & self.BIT[48] != 0) + (B & self.BIT[49] != 0) + (B & self.BIT[57] != 0)
        if w3 != 1 and b3 != 1:
            wunstable += (W & self.BIT[62] != 0) + (W & self.BIT[54] != 0) + (W & self.BIT[55] != 0)
            bunstable += (B & self.BIT[62] != 0) + (B & self.BIT[54] != 0) + (B & self.BIT[55] != 0)

        cdef double scoreunstable = - 30.0 * (wunstable - bunstable)

        # piece difference
        cdef double wpiece = (w0 + w1 + w2 + w3) * 100.0
        for i in range(len(self.WEIGHTS)):
            wpiece += self.WEIGHTS[i] * self.count_bit(W & self.P_RINGS[i])
        cdef double bpiece = (b0 + b1 + b2 + b3) * 100.0
        for i in range(len(self.WEIGHTS)):
            bpiece += self.WEIGHTS[i] * self.count_bit(B & self.P_RINGS[i])
        cdef double scorepiece = wpiece - bpiece

        # mobility
        cdef int wmob = self.count_bit(self.move_gen(W, B))
        cdef double scoremob = 20 * wmob

        return scorepiece + scoreunstable + scoremob

    cpdef to_bitboard(self, state):
        cdef int pieces[8][8]   # @NOTE 8-by-8 board
        pieces[0] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[1] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[2] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[3] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[4] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[5] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[6] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        pieces[7] = [0]*8  # @ST @NOTE we use 0 for empty, 1 for player 1 and -1 for player 2
        cdef unsigned long p1_placed = state[0]
        cdef unsigned long p2_placed = state[1]
        cdef int previous = state[2]
        cdef int player = state[3]
        cdef unsigned long index
        for r in xrange(self.board.rows):
            for c in xrange(self.board.cols):
                index = 1 << (self.board.cols * r + c)
                if index & p1_placed:
                    pieces[r][c] = 1  # 1 for white
                if index & p2_placed:
                    pieces[r][c] = -1 # -1 for black

        cdef unsigned long W = 0
        cdef unsigned long B = 0
        for r in range(8):
            for c in range(8):
                if pieces[c][r] == -1:
                    B |= self.BIT[8 * r + c]
                elif pieces[c][r] == 1:
                    W |= self.BIT[8 * r + c]

        return (W, B)

    def count_bit(self, b):
        b -=  (b >> 1) & 0x5555555555555555
        b  = (((b >> 2) & 0x3333333333333333) + (b & 0x3333333333333333))
        b  = ((b >> 4) + b)  & 0x0F0F0F0F0F0F0F0F
        return ((b * 0x0101010101010101) & self.FULL_MASK) >> 56

    cdef move_gen_sub(self, P, mask, dir):
        dir2 = long(dir * 2)
        cdef unsigned long flip1  = mask & (P << dir)
        cdef unsigned long flip2  = mask & (P >> dir)
        flip1 |= mask & (flip1 << dir)
        flip2 |= mask & (flip2 >> dir)
        cdef unsigned long mask1  = mask & (mask << dir)
        cdef unsigned long mask2  = mask & (mask >> dir)
        flip1 |= mask1 & (flip1 << dir2)
        flip2 |= mask2 & (flip2 >> dir2)
        flip1 |= mask1 & (flip1 << dir2)
        flip2 |= mask2 & (flip2 >> dir2)
        return (flip1 << dir) | (flip2 >> dir)

    cdef move_gen(self, P, O):
        cdef unsigned long mask = O & 0x7E7E7E7E7E7E7E7E
        return ((self.move_gen_sub(P, mask, 1)
                | self.move_gen_sub(P, O, 8)
                | self.move_gen_sub(P, mask, 7)
                | self.move_gen_sub(P, mask, 9)) & ~(P|O)) & self.FULL_MASK
