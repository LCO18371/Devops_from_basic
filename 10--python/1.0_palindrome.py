'''
Plaindrome
Find the size of such maximum number of bags that can be arranged.
Note: S consists of lowercase and/or uppercase English letters only.
Input Format: abccccdd
Constraints: 1 <= S.length <= 10^4
output: 7
'''
def longestPalindrome(s: str) -> int:   
    """
    :type s: str
    :rtype: int
    """
    count = 0
    odd = 0
    print(set(s))
    for i in set(s):
        if s.count(i) % 2 == 0:
            print(i, s.count(i))
            # even
            count += s.count(i)
        else:
            print(i, s.count(i))
            count += s.count(i) - 1
            odd = 1
    return count + odd
# Test cases
print(longestPalindrome("abccccdd"))  # Output: 7