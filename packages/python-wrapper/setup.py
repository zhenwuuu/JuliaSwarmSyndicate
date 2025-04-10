from setuptools import setup, find_packages

setup(
    name="juliaos",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "websockets>=10.0",
        "aiohttp>=3.8.0",
        "pydantic>=1.9.0",
        "asyncio>=3.4.3",
        "python-dotenv>=0.19.0",
        "nest-asyncio>=1.5.5",
        # LangChain dependencies
        "langchain>=0.0.267",
        "langchain-core>=0.0.10",
        "langchain-community>=0.0.10",
    ],
    extras_require={
        "llm": [
            "openai>=1.0.0",
            "anthropic>=0.5.0",
            "google-generativeai>=0.3.0",
            "cohere>=4.0.0",
            "replicate>=0.15.0",
        ],
        "adk": [
            "google-agent-sdk>=0.1.0",
        ],
    },
    author="JuliaOS Team",
    author_email="info@juliaos.com",
    description="Python wrapper for JuliaOS Framework",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/juliaos/juliaos",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    python_requires=">=3.8",
)
