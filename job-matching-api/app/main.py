# main.py
import logging
logging.basicConfig(level=logging.INFO)

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models import MatchRequest, MatchResponse
from .matcher import JobCandidateMatchingSystem
import os

app = FastAPI(
    title="Job Candidate Matching API",
    description="API for matching job candidates with job postings",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

matcher = JobCandidateMatchingSystem()

@app.get("/")
async def root():
    return {"message": "Welcome to the Job Candidate Matching API"}

@app.post("/match/", response_model=dict)
async def match_job_candidate(request: MatchRequest):
    try:
        logging.info(f"Received /match/ POST data:\nJob: {request.job}\nCandidate: {request.candidate}")

        match_result = matcher.calculate_match_score(
            request.job.model_dump(exclude_none=True),
            request.candidate.model_dump(exclude_none=True),
        )

        matching_skills = matcher.get_matching_skills(
            request.job.model_dump(exclude_none=True),
            request.candidate.model_dump(exclude_none=True),
        )

        match_result["matching_skills"] = matching_skills

        return match_result
    except Exception as e:
        logging.error(f"Error in /match/: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error calculating match: {str(e)}")

@app.post("/batch-match/")
async def batch_match_candidates(request: dict):
    try:
        logging.info(f"Received /batch-match/ POST data:\n{request}")

        job = request.get("job")
        candidates = request.get("candidates", [])

        if not job or not candidates:
            raise HTTPException(
                status_code=400, detail="Both job and candidates are required"
            )

        results = []
        for candidate in candidates:
            match_result = matcher.calculate_match_score(job, candidate)
            matching_skills = matcher.get_matching_skills(job, candidate)

            results.append(
                {
                    "candidate": candidate,
                    "match_score": match_result["overall_match_score"],
                    "category_scores": match_result["category_scores"],
                    "matching_skills": matching_skills,
                }
            )
        logging.info(f"Received /batch-match/ matches:\n{results}")
        return {"matches": results}
    
    except Exception as e:
        logging.error(f"Error in /batch-match/: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Error in batch matching: {str(e)}")