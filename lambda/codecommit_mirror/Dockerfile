FROM public.ecr.aws/lambda/python:3.12

RUN dnf install -y git && dnf clean all
RUN pip install --no-cache-dir git-remote-codecommit

COPY app.py ${LAMBDA_TASK_ROOT}/app.py

CMD ["app.handler"]

