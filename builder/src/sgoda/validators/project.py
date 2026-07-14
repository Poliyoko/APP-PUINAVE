from sgoda.core import BuilderConfig,ProjectBuilder
def validate_project(workspace): return ProjectBuilder(BuilderConfig.from_path(workspace)).validate()
