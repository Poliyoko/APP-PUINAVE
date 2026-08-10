from __future__ import annotations

import ast


class SqlSafetyGuard:
    """
    AST-based detector for obvious dynamic SQL passed directly to execute-like
    calls. It avoids flagging detector source, docs, tests and unrelated strings.
    """

    EXECUTE_NAMES = {"execute", "executemany"}

    @classmethod
    def contains_obvious_unsafe_execution(cls, text: str) -> bool:
        try:
            tree = ast.parse(text)
        except SyntaxError:
            return False

        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue

            func_name = ""
            if isinstance(node.func, ast.Attribute):
                func_name = node.func.attr
            elif isinstance(node.func, ast.Name):
                func_name = node.func.id

            if func_name not in cls.EXECUTE_NAMES or not node.args:
                continue

            first = node.args[0]

            if isinstance(first, ast.JoinedStr):
                return True

            if isinstance(first, ast.BinOp) and isinstance(
                first.op,
                (ast.Add, ast.Mod),
            ):
                return True

            if (
                isinstance(first, ast.Call)
                and isinstance(first.func, ast.Attribute)
                and first.func.attr == "format"
            ):
                return True

        return False
