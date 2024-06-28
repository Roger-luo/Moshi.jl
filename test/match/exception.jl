using Moshi.Match: PatternSyntaxError

@test sprint(showerror, PatternSyntaxError("X")) == "X"
