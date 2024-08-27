#if defined(FAST)

#define assert_eq(Lhs, Rhs, Why)

#define assert_neq(Lhs, Rhs, Why)

#define assert_gt(Lhs, Rhs, Why)

#define assert_lt(Lhs, Rhs, Why)

#define assert_gte(Lhs, Rhs, Why)

#define assert_lte(Lhs, Rhs, Why)

#else

#define assert_eq(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) == (Rhs), "equal to", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#define assert_neq(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) != (Rhs), "not equal to", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#define assert_gt(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) > (Rhs), "greater than", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#define assert_lt(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) < (Rhs), "less than", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#define assert_gte(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) >= (Rhs), "greater than or equal to", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#define assert_lte(Lhs, Rhs, Why) \
  ::neo::debug::assert((Lhs) <= (Rhs), "less than or equal to", #Why, #Lhs, #Rhs, (Lhs), (Rhs)) 

#endif
